-- ===========================
-- 查看 vim 信息
-- ===========================
vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim" -- 设置缓冲区为 vim 文件类型
	local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages) -- 将 Vim 消息填充到缓冲区
	vim.cmd("belowright split") -- 在下方打开一个新的窗口
	vim.api.nvim_win_set_buf(0, scratch_buffer) -- 将新窗口的缓冲区设置为刚才创建的缓冲区
	vim.opt_local.wrap = true -- 启用行自动换行
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe" -- 关闭缓冲区时自动删除该缓冲区
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer }) -- 设置快捷键 q 来关闭窗口
end, {})

-- ===========================
-- 切换 Quickfix 窗口
-- ===========================
-- -- 判断窗口是否打开
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win[win_type] == 1 then
			return true -- 如果指定类型窗口打开，返回 true
		end
	end
	return false -- 如果未找到指定类型窗口，返回 false
end
vim.api.nvim_create_user_command("ToggleQuickfix", function()
	if is_window_open("quickfix") then
		vim.cmd("cclose") -- 如果 Quickfix 窗口已打开，关闭该窗口
	else
		vim.cmd("copen") -- 如果 Quickfix 窗口未打开，打开该窗口
	end
end, { desc = "切换 Quickfix 窗口" })
-- -- ===========================
-- -- 切换 Location List 窗口
-- -- ===========================
vim.api.nvim_create_user_command("ToggleLoclist", function()
	if is_window_open("loclist") then
		vim.cmd("lclose") -- 如果 Location List 窗口已打开，关闭该窗口
	else
		local locationList = vim.fn.getloclist(0)
		if #locationList > 0 then
			vim.cmd("lopen") -- 如果有可用的 Location List，打开该窗口
		else
			vim.notify("当前没有 loclist 可用", vim.log.levels.WARN) -- 如果没有可用的 Location List，发出警告
		end
	end
end, { desc = "切换 Location List" })
