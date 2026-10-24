-- 每 tab 独立工作区：每个 tab 只显示自己的 buffer（bufferline 隔离），
-- 每个 tab 有独立 cwd（resession 会一并保存/恢复）。
--
-- 实现拆分于 core/tab_workspace/：
--   util.lua      —— buffer/会话判定
--   ownership.lua —— buffer 归属、listed 状态、会话导出/恢复
--   lsp.lua       —— 每 tab 的 LSP 生命周期
--   actions.lua   —— 关闭、切根目录、保存会话、新建/关闭/切换工作区
-- 本文件保留公共 API 与 setup/autocmd/resession 挂接。
local ownership = require("feat.tab_workspace.ownership")
local lsp = require("feat.tab_workspace.lsp")
local actions = require("feat.tab_workspace.actions")
local util = require("feat.tab_workspace.util")

local M = {}
M.config = {}

-- 是否已在 setup 里挂过 resession 钩子
local imported = false
local attached = false

local GROUP = "TabWorkspace"

-- 公共 API：其余实现委托给内部模块
M.relist = ownership.relist
M.export = ownership.export
M.rebuild = ownership.rebuild
M.close_buffer = actions.close_buffer
M.set_root = actions.set_root
M.prompt_root = actions.prompt_root
M.save_session = actions.save_session
M.new_workspace = actions.new_workspace
M.close_workspace = actions.close_workspace
M.alternate = actions.alternate
M.is_workspace_buf = util.is_workspace_buf
M.is_current_tab_buf = ownership.is_current_tab_buf

--- 从会话恢复每 tab 的归属（由 resession post_load 插件回调调用）
---@param map? table<string, string[]>
function M.import(map)
	if not ownership.replace(map) then
		return
	end
	imported = true
	ownership.relist()
end

function M.setup()
	M.config = vim.tbl_deep_extend("force", {
		lsp_stop_on_leave = true,
		lsp_restart_on_enter = true,
		lsp_stop_delay = 5000,
	}, M.config or {})

	lsp.configure(M.config)

	local cur_tab = vim.api.nvim_get_current_tabpage()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(cur_tab)) do
		if not util.is_float_win(win) then
			ownership.claim(cur_tab, vim.api.nvim_win_get_buf(win))
		end
	end

	local group = vim.api.nvim_create_augroup(GROUP, { clear = true })

	-- 任何进入窗口的 buffer 都自动归当前 tab；普通 buffer 一律 listed。
	-- 会话加载期间不要抢归属（resession 还在按名字恢复 buffer）。
	-- 浮窗（todo2 预览/hover、各类 peek 等）除外：它们内部常用真实文件 buffer
	-- （buftype == ""），若在这里 claim + listed，就会凭空出现在 bufferline 上。
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
		group = group,
		callback = function(args)
			if util.resession_loading() then
				return
			end
			if util.is_float_win(vim.api.nvim_get_current_win()) then
				return
			end
			ownership.claim(vim.api.nvim_get_current_tabpage(), args.buf)
			if util.is_workspace_buf(args.buf) then
				vim.bo[args.buf].buflisted = true
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(args)
			if ownership.is_toggling() then
				return
			end
			ownership.forget(args.buf)
		end,
	})

	-- 记住切走前的 tab，用于 :TabWorkspaceAlternate
	vim.api.nvim_create_autocmd("TabLeave", {
		group = group,
		callback = function()
			if not util.resession_loading() then
				ownership.set_last_tab(vim.api.nvim_get_current_tabpage())
			end
		end,
	})

	-- 切到另一个 tab 后同步 LSP：
	--   进入的 tab：恢复它需要、但离开期间被停掉的 client（FileType 不会再触发）
	--   离开的 tab：延迟停掉它独占的 client（给快速切回来留缓冲，TabEnter 会取消）
	vim.api.nvim_create_autocmd("TabEnter", {
		group = group,
		callback = function()
			if util.resession_loading() then
				return
			end
			local tab = vim.api.nvim_get_current_tabpage()
			-- relist 必须同步：TabEnter 在首帧绘制之前触发，此时改好 buflisted，
			-- 第一帧就是当前 tab 的正确集合；放到 schedule 里会先画一帧「所有 tab 的
			-- buffer」再刷新，这就是切 tab 时的闪烁。
			M.relist()
			vim.schedule(function()
				if vim.api.nvim_tabpage_is_valid(tab) and vim.api.nvim_get_current_tabpage() == tab then
					lsp.sync(tab)
				end
			end)
		end,
	})

	-- 新 tab 建立归属：此时窗口还没有 buffer，不必 claim。
	-- 关闭 tab 后清理归属，并把「被藏起来、又没窗口显示」的 buffer 真正删掉。
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			vim.schedule(ownership.prune_closed_tabs)
		end,
	})
end

--- 挂接 resession 的扩展保存/恢复钩子（只需调用一次）
---@return boolean
function M.attach_resession()
	if attached then
		return true
	end

	local ok, resession = pcall(require, "resession")
	if not ok then
		return false
	end
	if type(resession.add_hook) ~= "function" then
		vim.notify("resession.add_hook API 不可用，工作区恢复已跳过", vim.log.levels.WARN)
		return false
	end

	-- 必须用 post_load：扩展的 on_post_load 在 resession 仍处于 loading 状态时调用，
	-- 此时 relist 会被 resession_loading() 挡掉，bufferline 会先把所有 tab 的
	-- buffer 都画出来，直到下一次 TabEnter 才隔离。
	resession.add_hook("post_load", function()
		-- 会话里带了归属信息：load 已经把所有 buffer 在当前 tab 建好了，
		-- 用记录的归属重排 listed 状态（不能 rebuild，因为只有当前 tab）。
		if imported then
			imported = false
			M.relist()
		else
			M.rebuild()
		end
		ownership.set_last_tab(nil)
	end)

	attached = true
	return true
end

return M
