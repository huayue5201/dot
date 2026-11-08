-- lua/lsp_ext/features/runnables/go.lua
-- Go（gopls）代码透镜支持
--
-- gopls 的 "run test" / "run benchmark" 透镜发的是**客户端侧**命令
-- `gopls.run_tests`（v0.24 的参数是 { URI, Tests[], Benchmarks[] }，
-- 老版是 { URI, Range }），gopls 自己不会跑，需要客户端执行 `go test`。
--
-- 对比另外两个透镜命令（**不要**在这里接管）：
--   gopls.generate        v0.24 已由 server 自己执行（internal/server/command.go:871），
--                         参数 { Dir, Recursive }，Dir 是**目录** URI 而非文件；
--                         这里保留客户端版本只是为了在终端里看到输出（server 版
--                         只报 progress，且 requireSave 要求先存盘）。
--   gopls.regenerate_cgo  纯 server 侧（internal/server/command.go:502）：要 reset view
--                         让 `go list` 重新生成 cgo 定义，客户端无法复刻，注册 handler
--                         只会把它从 server 手里抢走然后什么也不做。
-- Neovim 原生不处理客户端侧命令，表现是透镜点了没反应。
--
-- 这里按声明处的函数名决定 go test 参数（前缀 Test / Benchmark / Fuzz），
-- 不依赖透镜标题，因为同一条命令对应三种透镜。

local M = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO)
end

---在终端里跑命令（与 rust 后端的 open_terminal 一致）
---@param cmd string[]
---@param cwd string|nil
local function open_terminal(cmd, cwd)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].bufhidden = "wipe"
	vim.fn.termopen(cmd, { cwd = cwd })
	vim.cmd.startinsert()
end

---读取指定 uri 的行（优先用已加载的 buffer）
---@param uri string
---@return string[]|nil lines
---@return string|nil fname
local function read_lines(uri)
	local ok, fname = pcall(vim.uri_to_fname, uri)
	if not ok or not fname then
		return nil
	end
	local bufnr = vim.fn.bufnr(fname)
	if bufnr ~= -1 and vim.api.nvim_buf_is_loaded(bufnr) then
		return vim.api.nvim_buf_get_lines(bufnr, 0, -1, false), fname
	end
	local rok, lines = pcall(vim.fn.readfile, fname)
	if not rok or type(lines) ~= "table" then
		return nil
	end
	return lines, fname
end

---从 range 起始行开始找 `func Name(` 的 Name
---@param lines string[]
---@param line integer 0-based
---@return string|nil
local function func_name_at(lines, line)
	-- 正常情况下 range.start 就指向 `func` 那一行；少数情况前面还有注释/空行，
	-- 因此只在当前行是空行或注释时才往下找（避免误扫到下一个函数）。
	for i = line + 1, math.min(line + 4, #lines) do
		local text = lines[i] or ""
		local name = text:match("^%s*func%s+([%w_]+)%s*%(")
		if name then
			return name
		end
		if not (text:match("^%s*$") or text:match("^%s*//")) then
			return nil
		end
	end
	return nil
end

---把名字数组拼成正则的 ^(A|B)$ 形式
---@param names string[]
---@return string
local function name_regex(names)
	return "^(" .. table.concat(names, "|") .. ")$"
end

---go test 的参数
---gopls 新版（>= v0.15）的 RunTestsArgs 直接给出 Tests / Benchmarks 名字列表，
---不再给 Range；老版只有 { URI, Range }，靠 range 起始行的函数名推断。
---@param tests string[]|nil
---@param benchmarks string[]|nil
---@param name string|nil 老版参数下从行号解析出的函数名
---@return string[]
local function test_args(tests, benchmarks, name)
	if (not tests or #tests == 0) and (not benchmarks or #benchmarks == 0) and name then
		if name:match("^Benchmark") then
			benchmarks = { name }
		else
			tests = { name }
		end
	end
	if (not tests or #tests == 0) and (not benchmarks or #benchmarks == 0) then
		return { "go", "test", "-v", "-count=1", "." }
	end
	local args = { "go", "test" }
	if tests and #tests > 0 then
		vim.list_extend(args, { "-run", name_regex(tests) })
	end
	if benchmarks and #benchmarks > 0 then
		vim.list_extend(args, { "-bench", name_regex(benchmarks) })
		if not tests or #tests == 0 then
			vim.list_extend(args, { "-run", "^$" })
		end
	end
	vim.list_extend(args, { "-v", "-count=1", "." })
	return args
end

---从参数对象里取字符串字段（大小写都认：新版 gopls 用 `URI` / `Dir`）
---@param t table
---@param keys string[]
---@return string|nil
local function str_field(t, keys)
	for _, k in ipairs(keys) do
		if type(t[k]) == "string" then
			return t[k]
		end
	end
	return nil
end

---从参数对象里取字符串数组字段
---@param t table
---@param keys string[]
---@return string[]|nil
local function list_field(t, keys)
	for _, k in ipairs(keys) do
		local v = t[k]
		if type(v) == "table" then
			local out = {}
			for _, item in ipairs(v) do
				if type(item) == "string" then
					out[#out + 1] = item
				end
			end
			if #out > 0 then
				return out
			end
		end
	end
	return nil
end

---取第一个带目标字段的参数对象
---gopls 的 arguments 形状是 [ { ... } ]（GenerateArgs 的字段是 Dir，RunTestsArgs 是 URI），
---但也兼容 arguments 直接给对象、或用小写键的客户端。
---@param args table|nil
---@return table|nil
local function first_arg(args)
	if type(args) ~= "table" then
		return nil
	end
	local keys = { "URI", "uri", "Dir", "dir" }
	if str_field(args, keys) then
		return args
	end
	for _, v in ipairs(args) do
		if type(v) == "table" and str_field(v, keys) then
			return v
		end
	end
	return nil
end

---处理 gopls.run_tests（test / benchmark / fuzz 三种透镜共用）
---@param command table
local function run_tests(command)
	local a = first_arg(command.arguments)
	if not a then
		notify("No target file in gopls.run_tests arguments", vim.log.levels.ERROR)
		return
	end
	local uri = str_field(a, { "URI", "uri" })
	local lines, fname = read_lines(uri)
	if not lines or not fname then
		notify("Cannot read test file: " .. tostring(uri), vim.log.levels.ERROR)
		return
	end
	local tests = list_field(a, { "Tests", "tests" })
	local benches = list_field(a, { "Benchmarks", "benchmarks" })
	-- 老版 gopls：只有 Range，从行号解析函数名
	local name
	if not tests and not benches then
		local range = a.Range or a.range
		local start_line = range and range.start and range.start.line or 0
		name = func_name_at(lines, start_line)
	end
	open_terminal(test_args(tests, benches, name), vim.fs.dirname(fname))
end

---处理 gopls.generate（client-side，对应 go generate）
---新版参数是 { Dir = "file:///dir/" , Recursive = bool }，Dir 是**目录** URI，不是文件；
---老版才是 { URI = 文件 , Recursive = bool }。
---@param command table
local function generate(command)
	local a = first_arg(command.arguments)
	local dir_uri = a and str_field(a, { "Dir", "dir" })
	local file_uri = a and str_field(a, { "URI", "uri" })
	if not dir_uri and not file_uri then
		notify("No target file in gopls.generate arguments", vim.log.levels.ERROR)
		return
	end
	local ok, path = pcall(vim.uri_to_fname, dir_uri or file_uri)
	if not ok or not path then
		notify("Cannot resolve path: " .. tostring(dir_uri or file_uri), vim.log.levels.ERROR)
		return
	end
	-- Dir 本身就是目录；老版 URI 是文件，取 dirname
	local dir = dir_uri and vim.fs.normalize(path) or vim.fs.dirname(path)
	local recursive = false
	for k, v in pairs(a or {}) do
		if (k == "Recursive" or k == "recursive") and v == true then
			recursive = true
		end
	end
	open_terminal({ "go", "generate", recursive and "./..." or "." }, dir)
end

M.commands = {
	["gopls.run_tests"] = run_tests,
	["gopls.test"] = run_tests, -- 旧版 gopls 的命令名
	["gopls.generate"] = generate,
}

M.keymaps = {}

---导出给测试
M._test_args = test_args
M._func_name_at = func_name_at

return M
