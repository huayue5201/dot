-- resession 扩展：终端窗口（面板 / 侧栏 / 普通分屏里的终端）。
--
-- 为什么需要它：resession 保存窗口布局时，每个 leaf 都必须「可保存」（buf_filter 通过
-- 或某个扩展认领），否则 line: `add_win_info_to_layout` 对 leaf 直接 return false，
-- **整个 tab 的布局作废**（保存成 wins=false，加载后该 tab 退化成单个空窗口）。
-- 而终端 buffer 是 unlisted、侧栏是 nofile，都不满足默认 buf_filter。
--
-- 这里只用 resession 文档化的三个钩子（is_win_supported / save_win / load_win），不碰
-- 它的内部实现：万一哪天扩展机制变了，本文件失效 = 退回修之前的行为（布局丢弃），
-- 不会连带把别的东西弄坏。终端进程本身没法存盘，恢复时起新 shell，位置/尺寸交给
-- resession 还原（见 tab-terminal.nvim 的 init.lua 的 M.restore_win 与 sidebar 的同名函数）。
local M = {}

---@param winid integer
---@param bufnr integer
---@return boolean
function M.is_win_supported(winid, bufnr)
	if vim.w[winid].tab_term_sidebar or vim.w[winid].tab_term_panel then
		return true
	end
	return vim.bo[bufnr].buftype == "terminal"
end

---@param winid integer
---@return table
function M.save_win(winid)
	-- sidebar / panel 是本模块的窗口，普通窗口里放终端（用户自己 :terminal）也记一笔
	if vim.w[winid].tab_term_sidebar then
		return { kind = "sidebar" }
	end
	return { kind = vim.w[winid].tab_term_panel and "panel" or "term" }
end

---@param winid integer
---@param config table|nil
---@return integer|nil
function M.load_win(winid, config)
	if not config then
		return winid
	end
	local ok
	if config.kind == "sidebar" then
		ok = pcall(function()
			require("tab_terminal.sidebar").restore_win(winid)
		end)
	else
		ok = pcall(function()
			require("tab_terminal").restore_win(winid, config.kind == "panel")
		end)
	end
	if not ok then
		-- 恢复失败就让 resession 保留这个空窗口（与没有扩展时的降级一致），不打断整个 load
		vim.notify("[tab_terminal] 终端窗口恢复失败", vim.log.levels.WARN)
	end
	return winid
end

return M
