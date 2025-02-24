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

-- 可视模式下复制时固定光标位置
local cursorPreYank
vim.keymap.set({ "n", "x" }, "y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y"
end, { expr = true })
vim.keymap.set({ "x" }, "Y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y$"
end, { expr = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		if vim.v.event.operator == "y" and cursorPreYank then
			vim.api.nvim_win_set_cursor(0, cursorPreYank)
		end
	end,
})

-- vim.api.nvim_create_autocmd("LspProgress", {
-- 	---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
-- 	callback = function(ev)
-- 		local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
-- 		vim.notify(vim.lsp.status(), "info", {
-- 			id = "lsp_progress",
-- 			title = "LSP Progress",
-- 			opts = function(notif)
-- 				notif.icon = ev.data.params.value.kind == "end" and " "
-- 					or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
-- 			end,
-- 		})
-- 	end,
-- })

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

local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win[win_type] == 1 then
			return true
		end
	end
	return false
end
-- Toggle Quickfix
vim.api.nvim_create_user_command("ToggleQuickfix", function()
	if is_window_open("quickfix") then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end, { desc = "Toggle Quickfix window" })
-- Toggle Location List
vim.api.nvim_create_user_command("ToggleLoclist", function()
	if is_window_open("loclist") then
		vim.cmd("lclose")
	else
		local locationList = vim.fn.getloclist(0)
		if #locationList > 0 then
			vim.cmd("lopen")
		else
			vim.notify("当前没有 loclist 可用", vim.log.levels.WARN)
		end
	end
end, { desc = "Toggle Location List" })

-- 查看 vim 信息
vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim"
	local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages)
	vim.cmd("belowright split") -- 或者使用 :belowright vsplit 进行垂直分屏
	vim.api.nvim_win_set_buf(0, scratch_buffer) -- 设置当前窗口的缓冲区为 scratch_buffer
	vim.opt_local.wrap = true
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe"
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer })
end, {})

vim.api.nvim_create_user_command("DeleteMarks", function()
	local marks_output = vim.fn.execute("marks")
	vim.notify("Current marks:\n" .. marks_output, vim.log.levels.INFO)
	local mark = vim.fn.input("Enter mark to delete: ")
	vim.cmd("redraw!")
	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		vim.notify("Deleted mark: " .. mark)
	else
		vim.api.nvim_echo({ { " No mark entered. Aborting.", "Error" } }, true, {})
	end
end, { desc = "Delete a specific mark" })

vim.api.nvim_create_user_command("DelAllMarks", function()
	vim.cmd("delmarks a-z")
	vim.cmd("delmarks A-Z")
	vim.notify(" All marks have been deleted!", vim.log.levels.INFO)
end, { desc = "删除所有标记" })

-- vim.api.nvim_create_user_command("ToggleTerm", function()
-- 	local height = vim.v.count > 0 and vim.v.count or 20
-- 	local term_window, term_buf
-- 	for _, win in ipairs(vim.api.nvim_list_wins()) do
-- 		local buf = vim.api.nvim_win_get_buf(win)
-- 		if vim.api.nvim_get_option_value("buftype", { buf = buf }) == "terminal" then
-- 			term_window, term_buf = win, buf
-- 			break
-- 		end
-- 	end
-- 	if term_window and vim.api.nvim_win_is_valid(term_window) then
-- 		if vim.api.nvim_win_get_buf(term_window) == term_buf then
-- 			vim.api.nvim_win_close(term_window, true)
-- 			vim.api.nvim_set_option_value("bufhidden", "hide", { buf = term_buf }) -- 使用新的 API 隐藏缓冲区
-- 		else
-- 			vim.api.nvim_set_current_win(term_window)
-- 		end
-- 	else
-- 		vim.api.nvim_command("new") -- 创建新窗口
-- 		vim.api.nvim_command("wincmd J") -- 移动到新窗口
-- 		term_window = vim.api.nvim_get_current_win()
-- 		vim.api.nvim_win_set_height(term_window, height)
-- 		vim.wo.winfixheight = true
-- 		vim.api.nvim_command("term") -- 创建新的终端
-- 		term_buf = vim.api.nvim_get_current_buf()
-- 		vim.api.nvim_set_option_value("buftype", "terminal", { buf = term_buf })
-- 		vim.api.nvim_set_option_value("bufhidden", "hide", { buf = term_buf })
-- 		vim.api.nvim_set_option_value("buflisted", false, { buf = term_buf })
-- 	end
-- end, { desc = "Toggle terminal window" })
