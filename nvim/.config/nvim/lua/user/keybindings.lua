-- user/keybindings
local M = {}

M.toggleLocationList = function()
	-- 获取当前的位置列表
	local locationList = vim.fn.getloclist(0)
	-- 检查是否存在位置列表
	if #locationList == 0 then
		-- 输出通知到消息窗口
		vim.api.nvim_out_write("当前没有loclist窗口\n")
		return
	end
	-- 获取窗口信息
	local windows = vim.fn.getwininfo()
	-- 检查位置列表窗口是否打开
	local locationListOpen = false
	for _, win in ipairs(windows) do
		if win.loclist == 1 then
			locationListOpen = true
			break
		end
	end
	-- 切换位置列表窗口
	if locationListOpen then
		vim.cmd("lclose")
	else
		vim.cmd("lopen")
	end
end

-- 切换 Quickfix 窗口的函数
M.toggleQuickfix = function()
	-- 获取窗口信息
	local windows = vim.fn.getwininfo()
	-- 检查 Quickfix 窗口是否已打开
	local quickfixOpen = false
	for _, win in ipairs(windows) do
		if win.quickfix == 1 then
			quickfixOpen = true
			break
		end
	end
	-- 切换 Quickfix 窗口的状态
	if quickfixOpen then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end

return M
