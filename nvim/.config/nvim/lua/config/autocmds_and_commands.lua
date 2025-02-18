-- 清理尾部空白字符
vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "保存文件时移除末尾的空白字符",
	group = vim.api.nvim_create_augroup("cleanSpace", { clear = true }),
	pattern = "*",
	command = "%s/\\s\\+$//e",
})

-- 记住最后的光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- 禁止换行时延续注释符号
vim.api.nvim_create_autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- 高亮复制内容
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		-- 只有当复制内容小于100个字符时才进行高亮
		if #vim.v.event.regcontents <= 1000 then
			vim.highlight.on_yank()
		end
	end,
})

-- 在特定文件类型中用 q 关闭窗口
vim.api.nvim_create_autocmd("FileType", {
	desc = "用q关闭窗口",
	pattern = "*",
	callback = function()
		local close_cmd = vim.bo.filetype == "man" and ":quit<CR>" or ":close<CR>"
		local filetypes = { "help", "startuptime", "qf", "lspinfo", "checkhealth", "man" }
		if vim.tbl_contains(filetypes, vim.bo.filetype) then
			vim.api.nvim_buf_set_keymap(0, "n", "q", close_cmd, { noremap = true, silent = true })
		end
	end,
})

-- Toggle Quickfix 和 Location List
vim.api.nvim_create_user_command("ToggleQuickfix", function()
	local quickfixOpen = false
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win.quickfix == 1 then
			quickfixOpen = true
			break
		end
	end
	if quickfixOpen then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end, { desc = "Toggle Quickfix window" })

vim.api.nvim_create_user_command("ToggleLoclist", function()
	local locationListOpen = false
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win.loclist == 1 then
			locationListOpen = true
			break
		end
	end
	if locationListOpen then
		vim.cmd("lclose")
	else
		local locationList = vim.fn.getloclist(0)
		if #locationList == 0 then
			vim.notify("当前没有 loclist 可用", vim.log.levels.WARN)
		else
			vim.cmd("lopen")
		end
	end
end, { desc = "Toggle Location List" })

-- 查看 vim 信息
vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim"
	local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages)
	vim.cmd("vertical sbuffer " .. scratch_buffer)
	vim.opt_local.wrap = true
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe"
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer })
end, {})

vim.api.nvim_create_user_command("DelMarks", function()
	local marks_output = vim.fn.execute("marks")
	vim.notify("Current marks:\n" .. marks_output, vim.log.levels.INFO)
	local mark = vim.fn.input("Enter mark to delete: ")
	vim.cmd("redraw!")
	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		vim.notify("Deleted mark: " .. mark)
	else
		vim.api.nvim_echo({ { "No mark entered. Aborting.", "Error" } }, true, {})
	end
end, { desc = "Delete a specific mark" })
