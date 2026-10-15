-- lua/lsp-config/features/runnables/rust.lua
-- Rust runnable / debuggable 支持（补齐 rust-analyzer 的 ▶ Run / ▶ Debug 代码透镜）
--
-- 背景：
--   rust-analyzer 只有在客户端 capability `experimental.commands.commands` 里声明了
--   `rust-analyzer.runSingle` / `rust-analyzer.debugSingle` 时，才会生成 ▶ Run / ▶ Debug
--   代码透镜（见 rust-lang/rust-analyzer 的 lsp/to_proto.rs code_lens 门控）。
--   并且点击透镜后需要客户端用 `vim.lsp.commands[...]` 真正执行。
--   Neovim 原生两者都没有，所以即使 `lens.run.enable = true` 也看不到/点了没反应。
--
-- 本后端做三件事（通用注册/键位分发见 features/runnables.lua）：
--   1. 提供 runSingle / debugSingle 命令处理器
--   2. 在 rust buffer 提供 <leader>rr（运行）/<leader>rd（调试）及选择器命令
--   3. 复用已注册的 codelldb 调试配置做 debugSingle
--
-- capability 的声明在 lsp/rust-analyzer.lua。

local M = {}

local function notify(msg, level)
	vim.notify(msg, level or vim.log.levels.INFO)
end

---@param runnable table
---@return boolean
local function is_cargo(runnable)
	return runnable ~= nil and runnable.args ~= nil and runnable.args.cargoArgs ~= nil
end

---JSON null 会被 Neovim 解码成 vim.NIL（在 Lua 里是真值），需要归一化为 nil
---@param v any
---@return any
local function norm(v)
	if v == vim.NIL then
		return nil
	end
	return v
end

---构建可执行命令（cargo 或 shell runnable）
---@param runnable table
---@return string[]|nil cmd
---@return string|nil cwd
---@return table<string,string>|nil env
local function build_command(runnable)
	local a = runnable.args
	if a.cargoArgs then
		local cmd = { norm(a.overrideCargo) or "cargo" }
		vim.list_extend(cmd, norm(a.cargoArgs) or {})
		vim.list_extend(cmd, norm(a.cargoExtraArgs) or {})
		local exe_args = norm(a.executableArgs)
		if exe_args and #exe_args > 0 then
			table.insert(cmd, "--")
			vim.list_extend(cmd, exe_args)
		end
		return cmd, norm(a.workspaceRoot), norm(a.environment)
	end
	local program = norm(a.program)
	if not program then
		return nil
	end
	local cmd = { program }
	vim.list_extend(cmd, norm(a.args) or {})
	return cmd, norm(a.cwd), norm(a.environment)
end

---在终端中运行命令
---@param cmd string[]
---@param cwd string|nil
---@param env table<string,string>|nil
local function open_terminal(cmd, cwd, env)
	vim.cmd("botright new")
	local buf = vim.api.nvim_get_current_buf()
	vim.bo[buf].bufhidden = "wipe"
	vim.fn.termopen(cmd, { cwd = cwd, env = env })
	vim.cmd.startinsert()
end

---运行一个 runnable
---@param runnable table|nil
function M.run_runnable(runnable)
	if not runnable then
		return
	end
	local cmd, cwd, env = build_command(runnable)
	if not cmd or #cmd == 0 then
		notify("无法构建运行命令（runnable 缺少可执行程序）", vim.log.levels.ERROR)
		return
	end
	open_terminal(cmd, cwd, env)
end

---解析 cargo --message-format=json 输出，找到可执行文件
---@param cargo_args string[]
---@param extra_args string[]|nil
---@param cwd string
---@param env table<string,string>|nil
---@param cb fun(exe: string|nil)
local function resolve_executable(cargo_args, extra_args, cwd, env, cb)
	local cmd = { "cargo" }
	vim.list_extend(cmd, cargo_args)
	vim.list_extend(cmd, extra_args or {})
	if not vim.tbl_contains(cmd, "--message-format=json") then
		-- 必须插在 `--` 之前，否则会被当成被调试程序的参数
		local insert_at = #cmd + 1
		for i, v in ipairs(cmd) do
			if v == "--" then
				insert_at = i
				break
			end
		end
		table.insert(cmd, insert_at, "--message-format=json")
	end

	notify("构建调试目标…")
	vim.system(cmd, { cwd = cwd, env = env, text = true }, function(sc)
		vim.schedule(function()
			if sc.code ~= 0 then
				notify("cargo 构建失败:\n" .. (sc.stderr or ""), vim.log.levels.ERROR)
				cb(nil)
				return
			end

			local exes, seen = {}, {}
			for _, line in ipairs(vim.split(sc.stdout or "", "\n", { plain = true })) do
				if line ~= "" then
					local ok, json = pcall(vim.json.decode, line)
					if ok and type(json) == "table" and json.reason == "compiler-artifact" and json.executable then
						local kind = (json.target and json.target.kind) or {}
						local is_test = json.profile and json.profile.test
						if (vim.tbl_contains(kind, "bin") or is_test) and not seen[json.executable] then
							seen[json.executable] = true
							table.insert(exes, json.executable)
						end
					end
				end
			end

			if #exes == 0 then
				notify("未找到可执行文件", vim.log.levels.WARN)
				cb(nil)
			elseif #exes == 1 then
				cb(exes[1])
			else
				vim.ui.select(exes, {
					prompt = "选择调试目标",
					format_item = vim.fs.basename,
				}, function(choice)
					cb(choice)
				end)
			end
		end)
	end)
end

---使用已注册的 codelldb 桌面调试配置启动调试
---@param exe string
---@param args table
---@param cwd string
---@param env table<string,string>|nil
---@param bufnr integer
local function start_debug(exe, args, cwd, env, bufnr)
	local ok, dap = pcall(require, "dap")
	if not ok then
		notify("未安装 nvim-dap，无法调试", vim.log.levels.ERROR)
		return
	end

	local base = { name = "Debug", type = "codelldb", request = "launch" }
	local provider = dap.providers and dap.providers.configs and dap.providers.configs["rust.desktop"]
	if provider then
		local configs = provider(bufnr)
		if configs and #configs == 0 then
			notify(
				"当前项目不是桌面项目，请用 <leader>dr 选择嵌入式调试配置",
				vim.log.levels.WARN
			)
			return
		end
		for _, c in ipairs(configs or {}) do
			if c.name == "Debug" then
				base = c
				break
			end
		end
	end

	local cfg = vim.tbl_extend("force", base, {
		program = exe,
		cwd = cwd,
		args = args or {},
		env = env,
	})

	-- nvim-dap 在「同名配置且已有会话」时会对同一个 codelldb 发 restart 请求，
	-- 而 codelldb 在进程仍在运行时会回 "a process is already being debugged"。
	-- 先同步关掉旧会话（会终止旧适配器/被调试进程），再强制开新会话。
	if dap.session() then
		dap.close()
	end
	dap.run(cfg, { new = true })
end

---调试一个 runnable
---@param runnable table|nil
---@param bufnr integer
function M.debug_runnable(runnable, bufnr)
	if not is_cargo(runnable) then
		notify("仅支持调试 cargo 目标", vim.log.levels.WARN)
		return
	end

	local a = runnable.args
	local cargo_args = vim.deepcopy(norm(a.cargoArgs))
	-- 调试前不能真的 run/test，转换构建命令
	if cargo_args[1] == "run" then
		cargo_args[1] = "build"
	elseif cargo_args[1] == "test" and not vim.tbl_contains(cargo_args, "--no-run") then
		table.insert(cargo_args, 2, "--no-run")
	end

	local extra = norm(a.cargoExtraArgs)
	local env = norm(a.environment)
	local cwd = norm(a.workspaceRoot) or vim.fn.getcwd()
	resolve_executable(cargo_args, extra, cwd, env, function(exe)
		if not exe then
			return
		end
		start_debug(exe, norm(a.executableArgs), cwd, env, bufnr)
	end)
end

---@param client vim.lsp.Client
---@param bufnr integer
---@param cb fun(runnables: table[])
local function request_runnables(client, bufnr, cb)
	client:request("experimental/runnables", {
		textDocument = vim.lsp.util.make_text_document_params(bufnr),
		position = nil, -- 取全部
	}, function(err, result)
		if err then
			notify("获取 runnables 失败: " .. tostring(err), vim.log.levels.ERROR)
			return
		end
		if not result or #result == 0 then
			notify("没有可运行目标", vim.log.levels.INFO)
			return
		end
		cb(result)
	end, bufnr)
end

---返回光标所在位置的 runnable（找不到则回退第一个）
---@param client vim.lsp.Client
---@param runnables table[]
---@return table
local function runnable_at_cursor(client, runnables)
	local pos = vim.lsp.util.make_position_params(0, client.offset_encoding or "utf-8").position
	local fallback
	for _, r in ipairs(runnables) do
		local tr = r.location and r.location.targetRange
		if tr and tr.start.line <= pos.line and tr["end"].line >= pos.line then
			if vim.startswith(r.label, "test-mod") then
				fallback = fallback or r
			else
				return r
			end
		end
	end
	return fallback or runnables[1]
end

---运行光标处目标
function M.run_at_cursor(client, bufnr)
	request_runnables(client, bufnr, function(runnables)
		M.run_runnable(runnable_at_cursor(client, runnables))
	end)
end

---调试光标处目标
function M.debug_at_cursor(client, bufnr)
	request_runnables(client, bufnr, function(runnables)
		M.debug_runnable(runnable_at_cursor(client, runnables), bufnr)
	end)
end

---选择并运行
function M.runnables(client, bufnr)
	request_runnables(client, bufnr, function(runnables)
		vim.ui.select(runnables, {
			prompt = "Runnables",
			format_item = function(r)
				return r.label
			end,
		}, function(choice)
			if choice then
				M.run_runnable(choice)
			end
		end)
	end)
end

---选择并调试
function M.debuggables(client, bufnr)
	request_runnables(client, bufnr, function(runnables)
		vim.ui.select(runnables, {
			prompt = "Debuggables",
			format_item = function(r)
				return r.label
			end,
		}, function(choice)
			if choice then
				M.debug_runnable(choice, bufnr)
			end
		end)
	end)
end

-- 由通用分发层 features/runnables.lua 注册：命令名 -> 处理器
M.commands = {
	["rust-analyzer.runSingle"] = function(command)
		M.run_runnable((command.arguments or {})[1])
	end,
	["rust-analyzer.debugSingle"] = function(command, bufnr)
		M.debug_runnable((command.arguments or {})[1], bufnr)
	end,
}

-- 该语言 buffer 的键位
M.keymaps = {
	{ lhs = "<leader>rr", fn = M.run_at_cursor, desc = "Rust: 运行光标处目标" },
	{ lhs = "<leader>rR", fn = M.runnables, desc = "Rust: 选择并运行" },
	{ lhs = "<leader>rd", fn = M.debug_at_cursor, desc = "Rust: 调试光标处目标" },
	{ lhs = "<leader>rD", fn = M.debuggables, desc = "Rust: 选择并调试" },
}

-- 导出内部函数供测试
M._build_command = build_command

return M
