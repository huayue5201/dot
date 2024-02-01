-- 快速切换 Quickfix 窗口的模块

local M = {}

-- 切换 Quickfix 窗口的函数
M.toggleQuickfix = function()
	-- 列出当前窗口
	local windows = vim.fn.getwininfo()

	-- 检查 Quickfix 窗口是否已打开
	local quickfixOpen = false
	for _, window in ipairs(windows) do
		if window.quickfix == 1 then
			quickfixOpen = true
			break
		end
	end

	-- 切换 Quickfix 窗口的状态
	if quickfixOpen then
		vim.cmd([[cclose]])
	else
		vim.cmd([[copen]])
	end
end

return M
