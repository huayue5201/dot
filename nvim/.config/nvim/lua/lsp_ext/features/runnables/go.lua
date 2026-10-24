-- lua/lsp_ext/features/runnables/go.lua
-- Go（gopls）代码透镜支持
--
-- gopls 的 "run test" / "run benchmark" / "run fuzz test" 透镜发的是**客户端侧**命令
-- `gopls.run_tests`（参数 { URI, Range }），gopls 自己不会跑，需要客户端执行
-- `go test`；"generate" 透镜是客户端侧的 `gopls.generate`，对应 `go generate`。
-- Neovim 原生不处理这些命令，表现是透镜点了没反应。
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

---go test 的参数：按函数名前缀决定走哪个开关
---@param name string|nil
---@return string[]
local function test_args(name)
	if not name then
		return { "go", "test", "-v", "-count=1", "." }
	end
	if name:match("^Benchmark") then
		return { "go", "test", "-bench", "^" .. name .. "$", "-run", "^$", "-count=1", "." }
	end
	-- Test / Fuzz / Example 都用 -run（Fuzz 函数用 -run 只跑 seed corpus，安全）
	return { "go", "test", "-run", "^" .. name .. "$", "-v", "-count=1", "." }
end

---取参数里的 { URI, Range }（也兼容 { Tests = {...} } 的新版写法）
---@param args table|nil
---@return string|nil uri
---@return table|nil range
local function target(args)
	local a = args or {}
	for _, v in pairs(a) do
		if type(v) == "table" and type(v.URI) == "string" then
			return v.URI, v.Range
		end
		if type(v) == "table" and type(v.uri) == "string" and type(v.range) == "table" then
			return v.uri, v.range
		end
	end
	return nil, nil
end

---处理 gopls.run_tests（test / benchmark / fuzz 三种透镜共用）
---@param command table
local function run_tests(command)
	local uri, range = target(command.arguments)
	if not uri then
		notify("gopls.run_tests 参数里没有目标文件", vim.log.levels.ERROR)
		return
	end
	local lines, fname = read_lines(uri)
	if not lines or not fname then
		notify("无法读取测试文件: " .. tostring(uri), vim.log.levels.ERROR)
		return
	end
	local start_line = range and range.start and range.start.line or 0
	local name = func_name_at(lines, start_line)
	open_terminal(test_args(name), vim.fs.dirname(fname))
end

---处理 gopls.generate（client-side，对应 go generate）
---@param command table
local function generate(command)
	local uri = target(command.arguments)
	if not uri then
		notify("gopls.generate 参数里没有目标文件", vim.log.levels.ERROR)
		return
	end
	local ok, fname = pcall(vim.uri_to_fname, uri)
	if not ok or not fname then
		notify("无法解析路径: " .. tostring(uri), vim.log.levels.ERROR)
		return
	end
	-- 第三个参数 Recursive：为 true 时跑整棵树
	local recursive = false
	for _, v in pairs(command.arguments or {}) do
		if type(v) == "table" and v.Recursive == true then
			recursive = true
		end
	end
	open_terminal({ "go", "generate", recursive and "./..." or "." }, vim.fs.dirname(fname))
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
