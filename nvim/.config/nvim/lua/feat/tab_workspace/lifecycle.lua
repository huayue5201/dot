-- buffer / 工作区的生命周期收尾：
--   prune        —— 清掉已关闭 tab 的归属，处理只属于它的孤儿 buffer
--   close_buffer —— 关闭单个 buffer（被其他 tab 共享时只从当前 tab 移除）
local util = require("feat.tab_workspace.util")
local state = require("feat.tab_workspace.state")
local listed = require("feat.tab_workspace.listed")

local M = {}

--- 清理已关闭 tab 的归属。
--- 只属于它、又不在任何窗口里的 buffer 不会自己消失（此前只是被 buflisted=false
--- 藏起来，仍占内存、留在 :ls! 里，也回不到 bufferline）：
---   有未保存修改 → 收编到当前 tab（不能静默丢数据，也不能让它变成孤儿）
---   没有修改     → 直接删掉
function M.prune()
	local valid = {}
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		valid[tab] = true
	end

	local orphans = {}
	for _, tab in ipairs(state.tabs()) do
		if not valid[tab] then
			for bufnr in pairs(state.drop_tab(tab)) do
				orphans[bufnr] = true
			end
		end
	end
	if state.last_tab() and not valid[state.last_tab()] then
		state.set_last_tab(nil)
	end

	-- 会话加载期间 tab 会被成批关掉/重建，还要按名字恢复 buffer：只清归属，不删 buffer
	if util.resession_loading() then
		return
	end

	local current = vim.api.nvim_get_current_tabpage()
	local rehomed = 0
	for bufnr in pairs(orphans) do
		if vim.api.nvim_buf_is_valid(bufnr) and #vim.fn.win_findbuf(bufnr) == 0 then
			if vim.bo[bufnr].modified then
				if state.claim(current, bufnr) then
					rehomed = rehomed + 1
				end
			elseif util.is_managed_buf(bufnr) then
				pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
			end
		end
	end
	if rehomed > 0 then
		vim.notify(string.format("%d unsaved buffer(s) moved into the current workspace", rehomed), vim.log.levels.WARN)
	end

	listed.relist()
end

--- 关闭 buffer。
--- 若它仍显示在其他 tab 的窗口里（同一 buffer 被多个 tab 共享），只从当前 tab
--- 移除、保留 buffer（归属交给仍显示它的 tab），不 bdelete。
---@param bufnr integer
function M.close_buffer(bufnr)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end
	local current = vim.api.nvim_get_current_tabpage()

	local other_tab
	for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
		if tab ~= current then
			for _, win in ipairs(vim.api.nvim_tabpage_list_wins(tab)) do
				if vim.api.nvim_win_get_buf(win) == bufnr then
					other_tab = tab
					break
				end
			end
		end
		if other_tab then
			break
		end
	end

	-- 会被真正删掉且有未保存修改时确认一次（共享 buffer 只是移出视图，不丢数据）
	if not other_tab and vim.bo[bufnr].modified then
		local name = vim.api.nvim_buf_get_name(bufnr)
		name = name == "" and "[No Name]" or vim.fn.fnamemodify(name, ":t")
		local choice =
			vim.fn.confirm(string.format("%s has unsaved changes. Close anyway?", name), "&Close\n&Cancel", 2)
		if choice ~= 1 then
			return
		end
	end

	if other_tab then
		-- 当前 tab 里显示它的窗口换成空 buffer，否则窗口里还留着它
		for _, win in ipairs(vim.api.nvim_tabpage_list_wins(current)) do
			if vim.api.nvim_win_get_buf(win) == bufnr then
				vim.api.nvim_win_call(win, function()
					vim.cmd("enew")
				end)
			end
		end
		if not state.claim(other_tab, bufnr) then
			state.forget(bufnr)
		end
	else
		pcall(vim.api.nvim_buf_delete, bufnr, { force = true })
	end

	listed.relist()
end

return M
