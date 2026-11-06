-- 工作区本地配置：<工作区根>/.nvim.lua
--
-- 对标 Emacs 的 .dir-locals.el、VS Code 的 .vscode/settings.json：
-- 配置跟随项目目录，而不是跟随编辑器实例。
--
-- 为什么不用 Neovim 自带的 'exrc'（本模块 setup 里把它关掉了）：
--   * exrc 只在启动时扫一次启动目录；之后 :tcd 进别的项目既不加载也不回滚，
--     与「每个 tab 一个工作区」冲突；
--   * exrc 执行裸 Lua，没有登记，离开项目时无法精确撤销。
-- 所以 .nvim.lua 由本模块独占：进入工作区时加载，离开（切 tab / 切根 / 关 tab）
-- 时逐项回滚，做到严格作用域。
--
-- 文件里通过 w.* 登记的改动才会被追踪与回滚：
--
--   w.opt({ tabstop = 4, shiftwidth = 4, expandtab = false })
--   w.global_opt({ spelllang = { "cjk", "en" } })
--   w.au("BufWritePre", { pattern = "*.rs" }, function(args) ... end)
--   w.cmd("Build", function(args) ... end, { desc = "构建" })
--   w.map("n", "<leader>B", "<cmd>Build<cr>", { desc = "构建" })
--   w.task({ name = "构建", cmd = { "make" } })          -- 进 :OverseerRun 的任务列表
--   w.launch({ name = "调试", filetype = "rust", ... })  -- 进 nvim-dap 的配置列表
--
-- 文件本身仍是可执行的 Lua（受 :trust 信任列表约束，未信任时 vim.secure.read
-- 返回 nil，我们直接跳过），除 w.* 之外的副作用不受回滚保护。
local M = {}

local FILE = ".nvim.lua"
local GROUP = "TabWorkspaceLocalSettings"

--- 当前生效的工作区配置
---@class TabWorkspaceLocalState
---@field root string 规范化后的根目录
---@field group integer 配置自己的 augroup（回滚时整体删除）
---@field opts table<string, any> w.opt 的声明
---@field globals table<string, any> w.global_opt 的声明
---@field maps table[] w.map 的声明
---@field bufs table<integer, table<string, any>> buffer -> 选项名 -> 原值
---@field cmd_names string[] w.cmd 创建的命令名
---@field tasks table[] w.task 的声明（登记到 overseer 的单一 provider 里）
---@field launches table[] w.launch 注入 dap.configurations 的配置（回滚时按引用摘除）

---@type TabWorkspaceLocalState?
local active = nil

-- 测试钩子：默认走 vim.secure.read（带 :trust 提示）
M._read = vim.secure.read

---@param dir string
---@return string
local function norm(dir)
	dir = (dir or ""):gsub("/+$", "")
	if dir == "" then
		return "/"
	end
	local ok, real = pcall(vim.uv.fs_realpath, dir)
	return ok and real or dir
end

--- path 是否在 dir 之下（按路径分段比较，避免 /a/bc 命中 /a/b）
---@param path string
---@param dir string
---@return boolean
local function is_under(path, dir)
	if dir == "/" then
		return true
	end
	return path == dir or path:sub(1, #dir + 1) == dir .. "/"
end

---@param st TabWorkspaceLocalState
---@param buf integer
---@return boolean
local function is_target(st, buf)
	if not vim.api.nvim_buf_is_valid(buf) or vim.bo[buf].buftype ~= "" then
		return false
	end
	local name = vim.api.nvim_buf_get_name(buf)
	return name ~= "" and is_under(norm(vim.fs.dirname(name) or ""), st.root)
end

---@param st TabWorkspaceLocalState
---@return integer[]
local function target_bufs(st)
	local bufs = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and is_target(st, buf) then
			bufs[#bufs + 1] = buf
		end
	end
	return bufs
end

--- 设置 buffer-local 选项，首次设置时记录原值
---@param st TabWorkspaceLocalState
---@param buf integer
---@param name string
---@param value any
local function set_buf_opt(st, buf, name, value)
	local snap = st.bufs[buf]
	if not snap then
		snap = {}
		st.bufs[buf] = snap
	end
	if snap[name] == nil then
		local ok, old = pcall(vim.api.nvim_get_option_value, name, { buf = buf })
		if not ok then
			vim.notify(string.format("workspace config: unknown option %s", name), vim.log.levels.WARN)
			return
		end
		snap[name] = old
	end
	pcall(vim.api.nvim_set_option_value, name, value, { buf = buf })
end

---@param st TabWorkspaceLocalState
---@param buf integer
local function apply_buf(st, buf)
	if not is_target(st, buf) then
		return
	end
	st.bufs[buf] = st.bufs[buf] or {}
	for name, value in pairs(st.opts) do
		set_buf_opt(st, buf, name, value)
	end
	for _, m in ipairs(st.maps) do
		for _, mode in ipairs(m.modes) do
			pcall(vim.keymap.set, mode, m.lhs, m.rhs, vim.tbl_extend("force", m.opts or {}, { buffer = buf }))
		end
	end
end

--- 任务里的 ${...} 占位符展开。
--- 变量名与 nvim-dap 的 ${file} / ${workspaceFolder} 保持一致，这样任务和调试配置
--- 是同一套写法；overseer 自己不做展开，所以这里补上。
---@param st TabWorkspaceLocalState
---@param value any
---@param file string 当前 buffer 的完整路径（可能为空）
---@return any
local function expand(st, value, file)
	if type(value) == "table" then
		local out = {}
		for k, v in pairs(value) do
			out[expand(st, k, file)] = expand(st, v, file)
		end
		return out
	end
	if type(value) ~= "string" then
		return value
	end
	local basename = file ~= "" and vim.fs.basename(file) or ""
	local vars = {
		workspaceFolder = st.root,
		workspaceFolderBasename = vim.fs.basename(st.root),
		file = file,
		fileBasename = basename,
		fileBasenameNoExtension = (basename:gsub("%.[^.]*$", "")),
		fileDirname = file ~= "" and vim.fs.dirname(file) or st.root,
		fileExtname = (basename:match("%.([^.]+)$") or ""),
	}
	return (
		value:gsub("%${([%w_]+)}", function(name)
			local v = vars[name]
			return v ~= nil and v or ("${" .. name .. "}")
		end)
	)
end

--- 暴露给 .nvim.lua 的登记 API
---@param st TabWorkspaceLocalState
---@return table
local function api(st)
	local w = {}

	--- 该根目录下所有 buffer 的 buffer-local 选项
	---@param opts table<string, any>
	function w.opt(opts)
		for name, value in pairs(opts or {}) do
			st.opts[name] = value
		end
		for _, buf in ipairs(target_bufs(st)) do
			apply_buf(st, buf)
		end
	end

	--- 全局选项（离开时恢复原值）
	---@param opts table<string, any>
	function w.global_opt(opts)
		for name, value in pairs(opts or {}) do
			if st.globals[name] == nil then
				local ok, old = pcall(vim.api.nvim_get_option_value, name, {})
				if not ok then
					vim.notify(string.format("workspace config: unknown option %s", name), vim.log.levels.WARN)
				else
					st.globals[name] = old
				end
			end
			pcall(vim.api.nvim_set_option_value, name, value, {})
		end
	end

	--- 自动命令，挂在配置自己的 augroup 里
	---@param event string|string[]
	---@param opts? table|fun(args: table)
	---@param fn? fun(args: table)
	function w.au(event, opts, fn)
		if type(opts) == "function" and fn == nil then
			opts, fn = {}, opts
		end
		opts = opts or {}
		opts = vim.tbl_extend("force", opts, { group = st.group })
		return vim.api.nvim_create_autocmd(event, opts)
	end

	--- 用户命令（离开时删除）
	---@param name string
	---@param fn fun(args: table)
	---@param opts? table
	function w.cmd(name, fn, opts)
		if vim.fn.exists(":" .. name) == 2 then
			vim.notify(
				string.format("workspace config: command :%s already exists, skipped", name),
				vim.log.levels.WARN
			)
			return
		end
		vim.api.nvim_create_user_command(name, fn, opts or {})
		st.cmd_names[#st.cmd_names + 1] = name
	end

	--- 该根目录下所有 buffer 的 buffer-local 键位（离开时删除）
	---@param modes string|string[]
	---@param lhs string
	---@param rhs any
	---@param opts? table
	function w.map(modes, lhs, rhs, opts)
		if type(modes) == "string" then
			modes = { modes }
		end
		local m = { modes = modes, lhs = lhs, rhs = rhs, opts = opts }
		st.maps[#st.maps + 1] = m
		for _, buf in ipairs(target_bufs(st)) do
			st.bufs[buf] = st.bufs[buf] or {}
			for _, mode in ipairs(modes) do
				pcall(vim.keymap.set, mode, lhs, rhs, vim.tbl_extend("force", opts or {}, { buffer = buf }))
			end
		end
	end

	--- 登记一个任务，出现在 :OverseerRun 的列表里（离开工作区后消失）
	---@param spec table { name, cmd, args?, cwd?, env?, components?, desc?, tags?, condition? }
	function w.task(spec)
		if type(spec) ~= "table" or type(spec.name) ~= "string" or spec.cmd == nil then
			vim.notify("workspace config: w.task requires { name, cmd }", vim.log.levels.WARN)
			return
		end
		st.tasks[#st.tasks + 1] = spec
		M._ensure_task_provider()
	end

	--- 登记一个调试配置，注入 dap.configurations[filetype]（离开工作区后摘除）
	---@param spec table nvim-dap 的配置，额外要求 filetype 字段
	function w.launch(spec)
		if type(spec) ~= "table" or type(spec.filetype) ~= "string" then
			vim.notify(
				"workspace config: w.launch requires { filetype, name, type, request, ... }",
				vim.log.levels.WARN
			)
			return
		end
		local ok, dap = pcall(require, "dap")
		if not ok then
			vim.notify(
				"workspace config: nvim-dap not loaded, skipped w.launch " .. tostring(spec.name),
				vim.log.levels.WARN
			)
			return
		end
		local config = vim.deepcopy(spec)
		config.filetype = nil
		dap.configurations[spec.filetype] = dap.configurations[spec.filetype] or {}
		table.insert(dap.configurations[spec.filetype], config)
		st.launches[#st.launches + 1] = { filetype = spec.filetype, config = config }
	end

	return w
end

--- 撤销当前生效的配置
function M.revert()
	local st = active
	if not st then
		return
	end
	active = nil
	pcall(vim.api.nvim_del_augroup_by_id, st.group)
	for buf, snap in pairs(st.bufs) do
		if vim.api.nvim_buf_is_valid(buf) then
			for name, old in pairs(snap) do
				pcall(vim.api.nvim_set_option_value, name, old, { buf = buf })
			end
			for _, m in ipairs(st.maps) do
				for _, mode in ipairs(m.modes) do
					pcall(vim.api.nvim_buf_del_keymap, buf, mode, m.lhs)
				end
			end
		end
	end
	for name, old in pairs(st.globals) do
		pcall(vim.api.nvim_set_option_value, name, old, {})
	end
	for _, name in ipairs(st.cmd_names) do
		pcall(vim.api.nvim_del_user_command, name)
	end
	-- dap.configurations 是纯 Lua 表：按引用摘除自己注入的那几条
	if #st.launches > 0 then
		local ok, dap = pcall(require, "dap")
		if ok then
			for _, item in ipairs(st.launches) do
				local list = dap.configurations[item.filetype]
				for i = (list and #list) or 0, 1, -1 do
					if rawequal(list[i], item.config) then
						table.remove(list, i)
						break
					end
				end
			end
		end
	end
end

local task_provider_registered = false

--- 把「当前工作区声明的任务」接到 overseer 的模板列表里。
--- overseer 没有反注册 API，所以只注册一个常驻 provider：它每次返回 active 里的任务，
--- 离开工作区后 active 为空 → 返回空表，任务自然从 :OverseerRun 消失。
function M._ensure_task_provider()
	if task_provider_registered then
		return
	end
	local ok, overseer = pcall(require, "overseer")
	if not ok then
		vim.notify_once("workspace config: overseer unavailable, w.task ignored", vim.log.levels.WARN)
		return
	end
	overseer.register_template({
		name = "Workspace Task",
		generator = function()
			local st = active
			if not st or #st.tasks == 0 then
				return {}
			end
			return vim.tbl_map(function(spec)
				return {
					name = spec.name,
					desc = spec.desc,
					tags = spec.tags,
					condition = spec.condition,
					builder = function()
						local file = vim.api.nvim_buf_get_name(0)
						return {
							cmd = expand(st, spec.cmd, file),
							args = expand(st, spec.args, file),
							cwd = expand(st, spec.cwd or "${workspaceFolder}", file),
							env = spec.env and expand(st, spec.env, file) or nil,
							components = spec.components or { "default" },
						}
					end,
				}
			end, st.tasks)
		end,
	})
	task_provider_registered = true
end

--- 按当前 tab 的根目录加载 / 卸载工作区配置
---@param tab? integer
function M.sync(tab)
	tab = tab or vim.api.nvim_get_current_tabpage()
	local dir = norm(require("feat.tab_workspace.root").cwd(tab))
	if active and active.root == dir then
		return
	end
	M.revert()

	local path = dir .. "/" .. FILE
	if vim.fn.filereadable(path) ~= 1 then
		return
	end
	local chunk = M._read(path)
	if type(chunk) ~= "string" then
		return -- 未信任：静默跳过（:trust 后重进该工作区即可）
	end
	-- 预置一个局部 w，让 .nvim.lua 里直接写 w.opt(...) / w.cmd(...)
	local fn, err = loadstring("local w = ...\n" .. chunk, "@" .. path)
	if not fn then
		vim.notify(string.format("workspace config %s: %s", path, err), vim.log.levels.ERROR)
		return
	end

	---@type TabWorkspaceLocalState
	local st = {
		root = dir,
		group = vim.api.nvim_create_augroup(GROUP .. "_" .. vim.api.nvim_tabpage_get_number(tab), { clear = true }),
		opts = {},
		globals = {},
		maps = {},
		bufs = {},
		cmd_names = {},
		tasks = {},
		launches = {},
	}
	active = st

	local ok, run_err = pcall(fn, api(st))
	if not ok then
		vim.notify(string.format("workspace config %s: %s", path, run_err), vim.log.levels.ERROR)
	end

	if #st.tasks > 0 then
		M._ensure_task_provider()
	end

	for _, buf in ipairs(target_bufs(st)) do
		apply_buf(st, buf)
	end

	-- 之后打开 / 新建的、位于该根下的 buffer 也自动套用
	if next(st.opts) ~= nil or #st.maps > 0 then
		vim.api.nvim_create_autocmd({ "BufReadPost", "FileType" }, {
			group = st.group,
			callback = function(args)
				apply_buf(st, args.buf)
			end,
		})
	end
end

--- 打开（不存在则创建）当前工作区的 .nvim.lua
function M.edit()
	local dir = require("feat.tab_workspace.root").cwd(vim.api.nvim_get_current_tabpage())
	local path = dir:gsub("/+$", "") .. "/" .. FILE
	if vim.fn.filereadable(path) ~= 1 then
		vim.fn.writefile({
			"-- Workspace-local config: applies only under " .. dir .. ", rolled back on leave.",
			"-- Only changes registered through w.* are tracked; anything else is not reverted.",
			"-- Full reference: ~/.config/nvim/lua/feat/tab_workspace/nvim-lua.md",
			"",
			"-- w.opt({ tabstop = 4, shiftwidth = 4 })",
			'-- w.global_opt({ spelllang = { "cjk", "en" } })',
			'-- w.au("BufWritePre", { pattern = "*.rs" }, function(args) end)',
			'-- w.cmd("Build", function(args) end, { desc = "Build" })',
			'-- w.map("n", "<leader>B", "<cmd>Build<cr>", { desc = "Build" })',
			'-- w.task({ name = "Build", cmd = { "make" }, cwd = "${workspaceFolder}" })',
			'-- w.launch({ name = "Debug", filetype = "rust", type = "codelldb", request = "launch" })',
		}, path)
	end
	vim.cmd.edit(vim.fn.fnameescape(path))
end

--- 重新加载当前工作区的 .nvim.lua
function M.reload()
	M.revert()
	M.sync()
end

--- 关掉 exrc 并把 .nvim.lua 的加载/卸载挂在 tab 生命周期上
function M.setup()
	-- exrc 只认启动目录、且不可回滚，与工作区模型冲突：由本模块独占
	vim.o.exrc = false

	local group = vim.api.nvim_create_augroup(GROUP, { clear = true })
	local function resync()
		if require("feat.tab_workspace.util").resession_loading() then
			return
		end
		M.sync()
	end
	vim.api.nvim_create_autocmd({ "TabEnter", "DirChanged" }, { group = group, callback = resync })
	vim.api.nvim_create_autocmd("VimEnter", { group = group, once = true, callback = resync })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "TabWorkspaceRoot",
		callback = function()
			M.sync()
		end,
	})

	M.sync()
end

return M
