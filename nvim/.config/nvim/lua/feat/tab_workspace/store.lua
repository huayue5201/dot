-- 会话存储适配层：**唯一** require("resession") 的地方。
--
-- 为什么要有这一层：tab_workspace 需要 resession 没提供的几个能力
-- （load 侧 buffer 过滤、失效 cwd 兜底、干净 tab 复用、按归属校验的 autosave），
-- 这些能力以前以猴补的形式散在 plugins/tools/resession.lua 和 session_guard.lua 里。
-- 收口到这里之后：
--   * 上层只认 store 的 API，不再直接碰 resession 内部；
--   * 以后要 fork / 换实现，只改这一个文件；
--   * 「我们的 schema」只在这里做读侧归一化，写侧仍由 extensions 负责。
--
-- 分工：
--   store          —— 存取原语 + 对 resession 内部行为的修正
--   session.lua    —— 归属的导出/恢复（schema v2）
--   session_guard  —— 归属策略（fits）与 autosave 调度
--   workspace.lua  —— 用户动作
local M = {}

local installed = false

---@class TabWorkspaceStoreConfig
---@field dir? string

local DEFAULT_CONFIG = {
	dir = "session",

	-- autosave 由 session_guard 实现（写前要校验会话归属），这里必须关掉。
	autosave = { enabled = false },

	-- 注意：不要包含 "buflisted"。buflisted 的唯一 owner 是 listed.lua
	-- （会话载入结束后由 post_load 重排），resession 再存一份只会互相覆盖。
	options = {
		"binary",
		"bufhidden",
		"cmdheight",
		"diff",
		"filetype",
		"modifiable",
		"previewwindow",
		"readonly",
		"scrollbind",
		"winfixheight",
		"winfixwidth",
	},

	-- 保存侧的 buffer 口径与工作区一致（排除终端/面板/无名 buffer）
	buf_filter = function(bufnr)
		return require("feat.tab_workspace.util").is_saved_buf(bufnr)
	end,

	load_detail = true,
	load_order = "modification_time",

	extensions = {
		quickfix = {},
		-- 默认 enable_in_tab = false 时 tab 作用域会话（<leader>lss）不会导出归属
		tab_workspace = { enable_in_tab = true },
		tw_terminal = {},
	},
}

---@return table? resession
function M.require()
	local ok, resession = pcall(require, "resession")
	return ok and resession or nil
end

---@param path string
---@return string?
local function norm(path)
	if type(path) ~= "string" or path == "" then
		return nil
	end
	path = path:gsub("/+$", "")
	local ok, real = pcall(vim.uv.fs_realpath, path)
	return (ok and real) or path
end

function M.sanitize_cwd(data)
	if type(data) ~= "table" then
		return data
	end
	local function valid(dir)
		return type(dir) == "string" and dir ~= "" and vim.fn.isdirectory(dir) == 1
	end

	local fallback
	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" and valid(tab.cwd) then
			fallback = tab.cwd
			break
		end
	end
	fallback = fallback or vim.fn.getcwd()

	for _, tab in ipairs(data.tabs or {}) do
		if type(tab) == "table" and type(tab.cwd) == "string" and not valid(tab.cwd) then
			tab.cwd = nil
		end
	end

	if type(data.global) == "table" then
		if not valid(data.global.cwd) then
			data.global.cwd = fallback
		end
	elseif fallback then
		data.global = { cwd = fallback }
	end
	return data
end

--- 载入侧的清洗（resession 没有 load 侧的 buffer filter）。
--
-- 它会对每个存下的 buffer 做 bufadd + bufload，而 bufload 一个 term:// 名字
-- 会把 shell 真拉起来（症状：加载旧会话时凭空打开一个终端）。
-- files.load_json_file 是 load 的唯一读入口，在这里洗一遍。
function M.install_load_filter()
	if installed then
		return
	end
	local ok, files = pcall(require, "resession.files")
	if not ok then
		return
	end
	local load_json_file = files.load_json_file
	files.load_json_file = function(path)
		local data = load_json_file(path)
		if type(data) == "table" then
			pcall(require("feat.tab_workspace.session").strip_terminal_bufs, data)
			M.sanitize_cwd(data)
		end
		return data
	end
	installed = true
end

--- 载入后把「全局 cwd」归位到当前 tab 的根。
--
-- resession 保存的 global.cwd 其实是「保存时活动 tab 的根」（getcwd(-1, -1)），
-- 载入时却用它 :cd 整个实例；之后 :tabnew 或没有 tab-local 的窗口就会继承
-- 那个上一个项目的目录，表现为「切回来却落在别的项目」。
function M.fix_global_cwd()
	local ok, dir = pcall(vim.fn.getcwd)
	if ok and type(dir) == "string" and dir ~= "" and vim.fn.isdirectory(dir) == 1 then
		pcall(vim.api.nvim_set_current_dir, dir)
	end
end

--- 清掉残留的僵尸 term:// buffer（旧版本写入 / bufadd 造出的空壳）
function M.clean_zombie_terms()
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		local name = vim.api.nvim_buf_get_name(bufnr)
		if name:find("^term://") and vim.bo[bufnr].buftype == "" and not vim.b[bufnr].terminal_job_id then
			pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
		end
	end
end

--- tab 作用域会话载入前：把当前 tab 变成 resession 眼中的「干净 tab」。
--
-- resession 对 tab 作用域会话走 open_clean_tab()：当前 tab 不是
-- 「单窗口 + 无名空 buffer」就 :tabnew，于是每载一次多一个 tab。
-- 这里先 only + :enew!，让 load 复用当前 tab；原有 buffer 仍留在 buffer 列表里，
-- 不删除、不丢改动（只是不再显示）。
function M.reuse_current_tab()
	if #vim.api.nvim_tabpage_list_wins(0) > 1 then
		pcall(vim.cmd.only, { mods = { emsg_silent = true } })
	end
	local buf = vim.api.nvim_get_current_buf()
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local is_clean = vim.api.nvim_buf_get_name(buf) == ""
		and vim.bo[buf].buftype == ""
		and #lines == 1
		and lines[1] == ""
	if is_clean then
		return
	end
	pcall(vim.cmd.enew, { bang = true })
end

--- 注册 store 自己需要的 post_load 钩子（cwd 归位 + 僵尸终端清理）
function M.register_hooks()
	local resession = M.require()
	if not resession or type(resession.add_hook) ~= "function" then
		return false
	end
	resession.add_hook("post_load", function()
		vim.schedule(function()
			pcall(M.fix_global_cwd)
			pcall(M.clean_zombie_terms)
		end)
	end)
	return true
end

--- 完整初始化：setup + load 侧清洗 + 默认 hook。
---@param config? table 覆盖 DEFAULT_CONFIG 的字段
---@return boolean ok
function M.setup(config)
	local resession = M.require()
	if not resession then
		return false
	end
	local cfg = vim.tbl_deep_extend("force", DEFAULT_CONFIG, config or {})
	-- 列表类字段整体替换，不要按索引深合并
	if config and config.options then
		cfg.options = config.options
	end
	resession.setup(cfg)
	M.install_load_filter()
	M.register_hooks()
	return true
end

-- ================= 业务 API =================

---@param name string
---@param opts? { dir?: string }
---@return string? path
function M.session_file(name, opts)
	local ok, util = pcall(require, "resession.util")
	if not ok then
		return nil
	end
	local ok_path, path = pcall(util.get_session_file, name, (opts or {}).dir)
	return ok_path and path or nil
end

--- 读会话文件（已含 terminal 清洗与 cwd 兜底）
---@param name string
---@param opts? { dir?: string }
---@return table?
function M.read(name, opts)
	local ok, files = pcall(require, "resession.files")
	if not ok then
		return nil
	end
	local path = M.session_file(name, opts)
	if not path then
		return nil
	end
	local ok_read, data = pcall(files.load_json_file, path)
	return ok_read and type(data) == "table" and data or nil
end

---@param opts? { dir?: string }
---@return string[]
function M.list(opts)
	local resession = M.require()
	if not resession then
		return {}
	end
	local ok, sessions = pcall(resession.list, opts)
	return ok and type(sessions) == "table" and sessions or {}
end

---@param name string
---@param opts? { dir?: string }
---@return boolean ok
---@return string? err
function M.delete(name, opts)
	local resession = M.require()
	if not resession then
		return false, "resession unavailable"
	end
	local o = vim.tbl_extend("keep", opts or {}, { notify = false })
	return pcall(resession.delete, name, o)
end

---@return string?
function M.current()
	local resession = M.require()
	if not resession then
		return nil
	end
	local ok, name = pcall(resession.get_current)
	return ok and name or nil
end

---@return boolean
function M.is_loading()
	local resession = M.require()
	if not resession then
		return false
	end
	local ok, loading = pcall(resession.is_loading)
	return ok and loading or false
end

---@param opts? table
function M.save_all(opts)
	local resession = M.require()
	if not resession then
		return
	end
	pcall(resession.save_all, opts)
end

---@param name string
---@param opts? table
function M.save(name, opts)
	local resession = M.require()
	if not resession then
		return
	end
	pcall(resession.save, name, opts)
end

---@param name string
---@param opts? table
function M.save_tab(name, opts)
	local resession = M.require()
	if not resession then
		return
	end
	pcall(resession.save_tab, name, opts)
end

--- 载入会话：tab 作用域会话复用当前 tab，整会话默认 attach。
---@param name string
---@param opts? table
function M.load(name, opts)
	local resession = M.require()
	if not resession then
		return
	end
	local o = vim.tbl_extend("keep", opts or {}, { attach = true })
	local data = M.read(name, o)
	if type(data) == "table" and data.tab_scoped then
		M.reuse_current_tab()
	end
	resession.load(name, o)
end

--- 注册额外的 post_load 钩子
---@param fn fun()
function M.on_post_load(fn)
	local resession = M.require()
	if resession and type(resession.add_hook) == "function" then
		resession.add_hook("post_load", fn)
	end
end

M.norm = norm

return M
