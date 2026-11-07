-- 每 tab 独立工作区：每个 tab 只显示自己的 buffer（bufferline 隔离），
-- 每个 tab 有独立 cwd（resession 会一并保存/恢复）。
--
-- 代码布局（lua/feat/tab_workspace/）：
--   util.lua      —— buffer / 窗口 / 会话加载状态的判定
--   state.lua     —— buffer 归属表（tab -> bufnr 集合）、最近访问的 tab
--   listed.lua    —— buflisted 同步（"listed = 当前 tab 可见" 的唯一实现）
--   lifecycle.lua —— 关闭 buffer、清理已关闭 tab 的孤儿 buffer
--   session.lua   —— resession 扩展的归属导出/恢复
--   lsp.lua       —— 每 tab 的 LSP 生命周期
--   root.lua      —— 按当前文件判定项目根（marker / LSP）并自动切 tab 根目录
--   workspace.lua —— 切根目录、新建/关闭/切换工作区、保存/载入会话
--   session_guard.lua —— 会话归属校验与 autosave 策略
--   store.lua     —— 唯一一处 resession 适配层（setup/读写/load 侧修正）
--   local_settings.lua —— 工作区本地配置（<根>/.nvim.lua）的加载与回滚
-- 本文件只留公共 API 与 setup/autocmd/resession 挂接。
local util = require("feat.tab_workspace.util")
local state = require("feat.tab_workspace.state")
local listed = require("feat.tab_workspace.listed")
local lifecycle = require("feat.tab_workspace.lifecycle")
local session = require("feat.tab_workspace.session")
local lsp = require("feat.tab_workspace.lsp")
local workspace = require("feat.tab_workspace.workspace")
local root = require("feat.tab_workspace.root")
local roots = require("feat.tab_workspace.roots")
local local_settings = require("feat.tab_workspace.local_settings")

local M = {}

---@type TabWorkspaceConfig
M.config = {}

local GROUP = "TabWorkspace"

-- 是否已在 setup 里挂过 resession 钩子
local attached = false

-- 公共 API：实现委托给内部模块
M.relist = listed.relist
M.visible_buffers = listed.visible_buffers
M.close_buffer = lifecycle.close_buffer
M.set_root = workspace.set_root
M.prompt_root = workspace.prompt_root
M.rename_workspace = workspace.rename_workspace
M.set_workspace_name = workspace.set_workspace_name
M.save_session = workspace.save_session
M.load_session = workspace.load_session
M.new_workspace = workspace.new_workspace
M.close_workspace = workspace.close_workspace
M.picker = workspace.picker
M.delete_session = workspace.delete_session
M.edit_local_settings = local_settings.edit
M.reload_local_settings = local_settings.reload
M.alternate = workspace.alternate
M.attach_root = workspace.attach_root
M.detach_root = workspace.detach_root
M.roots = workspace.roots
M.workspace_tree = workspace.tree
M.resolve_root = root.resolve
M.root_back = root.back
M.root_unpin = root.unpin
M.export = session.export
M.rebuild = session.rebuild
M.is_workspace_buf = util.is_managed_buf
M.is_managed_buf = util.is_managed_buf

---@class TabWorkspaceConfig
---@field lsp_stop_on_leave boolean 离开 tab 后是否停掉它不再用的 LSP client
---@field lsp_restart_on_enter boolean 进入 tab 时是否恢复被停掉的 client
---@field lsp_stop_delay integer 延迟多久（毫秒）停，给快速切回来留缓冲
---@field auto_root boolean 是否按当前文件自动切换 tab 根目录
---@field root_markers string[]|nil 判定项目根的标记文件（nil = 用 root.lua 的默认列表）

---@param opts? TabWorkspaceConfig
function M.setup(opts)
	M.config = vim.tbl_deep_extend("force", {
		lsp_stop_on_leave = true,
		lsp_restart_on_enter = true,
		lsp_stop_delay = 5000,
		auto_root = true,
		root_markers = nil,
	}, M.config or {}, opts or {})
	lsp.configure(M.config)
	root.setup({ enabled = M.config.auto_root, markers = M.config.root_markers })
	-- 项目本地配置（.nvim.lua）随工作区加载/回滚；顺带接管 'exrc'
	local_settings.setup()

	-- 启动时把当前 tab 已显示的 buffer 归位
	local current = vim.api.nvim_get_current_tabpage()
	for _, bufnr in ipairs(state.window_buffers(current)) do
		state.claim(current, bufnr)
	end

	local group = vim.api.nvim_create_augroup(GROUP, { clear = true })

	-- 进入窗口的 buffer 自动归当前 tab，并保持 listed。
	-- 浮窗/侧栏除外：它们内部常显示真实文件 buffer（buftype == ""），
	-- 在这里 claim + listed 会让它凭空出现在 bufferline 上。
	-- 会话加载期间不要抢归属（resession 还在按名字恢复 buffer）。
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
		group = group,
		callback = function(args)
			if util.resession_loading() then
				return
			end
			local win = vim.api.nvim_get_current_win()
			if util.is_ephemeral_win(win) then
				return
			end
			local tab = vim.api.nvim_win_get_tabpage(win)
			if state.claim(tab, args.buf) then
				-- 刚在真实窗口里显示的 buffer，必然属于当前 tab 的可见集合；
				-- 但终端这类「不占 bufferline」的 buffer 保持 unlisted
				vim.bo[args.buf].buflisted = not listed.is_bar_hidden(args.buf)
			end
		end,
	})

	vim.api.nvim_create_autocmd({ "BufDelete", "BufWipeout" }, {
		group = group,
		callback = function(args)
			if listed.is_toggling() then
				return
			end
			state.forget(args.buf)
		end,
	})

	-- 打开/切到某个文件时：它不在本 tab 的根内，就把根切到它所属的项目根。
	-- 「在根内」是绝大多数情况，此时零动作（见 root.maybe_follow）。
	vim.api.nvim_create_autocmd({ "BufWinEnter", "BufEnter" }, {
		group = group,
		callback = function(args)
			if util.resession_loading() then
				return
			end
			root.maybe_follow(args.buf)
		end,
	})

	-- 记住切走前的 tab，用于 :TabWorkspaceAlternate
	vim.api.nvim_create_autocmd("TabLeave", {
		group = group,
		callback = function()
			if not util.resession_loading() then
				state.set_last_tab(vim.api.nvim_get_current_tabpage())
			end
		end,
	})

	-- 切到另一个 tab 后：同步 buflisted + 同步 LSP。
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
			listed.relist()
			vim.schedule(function()
				if not vim.api.nvim_tabpage_is_valid(tab) or vim.api.nvim_get_current_tabpage() ~= tab then
					return
				end
				-- 有些切 tab 路径（:tabnew、会话恢复、:tab sbuffer）触发 TabEnter 时，
				-- 窗口里还是上一个 tab 的 buffer，那一刻的窗口快照会把旧 buffer 算进来。
				-- 事件循环结束后窗口才真正拿到本 tab 的 buffer，此时再校一次归属与 listed。
				for _, bufnr in ipairs(state.window_buffers(tab)) do
					state.claim(tab, bufnr)
				end
				listed.relist()
				lsp.sync(tab)
			end)
		end,
	})

	-- 关闭 tab 后：清归属（顺带删掉孤儿 buffer / 收编未保存的），停掉它独占的 LSP
	vim.api.nvim_create_autocmd("TabClosed", {
		group = group,
		callback = function()
			root.prune()
			vim.schedule(function()
				lifecycle.prune()
				lsp.on_tab_closed()
			end)
		end,
	})

	-- 主根变了：如果新主根也在辅助根里，从辅助列表里摘掉（不重复显示同一目录）
	vim.api.nvim_create_autocmd({ "DirChanged", "User" }, {
		group = group,
		pattern = { "DirChanged", "TabWorkspaceRoot" },
		callback = function(args)
			if args.event == "User" and args.pattern ~= "TabWorkspaceRoot" then
				return
			end
			roots.reconcile(vim.api.nvim_get_current_tabpage())
		end,
	})
end

--- 挂接 resession 的扩展保存/恢复钩子（只需调用一次）
---@return boolean ok
function M.attach_resession()
	if attached then
		return true
	end

	local ok, resession = pcall(require, "resession")
	if not ok then
		return false
	end
	if type(resession.add_hook) ~= "function" then
		vim.notify("resession.add_hook unavailable, workspace restore skipped", vim.log.levels.WARN)
		return false
	end

	-- 用 post_load 而不是扩展的 on_post_load：后者在 resession 仍然 is_loading()
	-- 时调用，relist 会被挡掉，bufferline 会先把所有 tab 的 buffer 画出来。
	resession.add_hook("post_load", function()
		session.on_post_load()
		-- 会话恢复会切换各 tab 的根，配置要跟着落到最终的工作区
		local_settings.sync()
	end)

	attached = true
	return true
end

return M
