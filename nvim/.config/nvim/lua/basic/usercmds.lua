vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "保存文件时移除末尾的空白字符",
	group = vim.api.nvim_create_augroup("cleanSpace", { clear = true }),
	pattern = "*",
	command = "%s/\\s\\+$//e",
})

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "特定buffer内禁用状态列",
	callback = function()
		local special_filetypes = { "neo-tree", "aerial", "toggleterm", "qf", "help", "man" }
		if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
			vim.wo.statuscolumn = ""
		end
	end,
})

vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = { "*" },
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

vim.api.nvim_create_autocmd("FileType", {
	desc = "用q关闭窗口",
	pattern = { "help", "startuptime", "qf", "lspinfo", "checkhealth" },
	command = [[nnoremap <buffer><silent> q :close<CR>]],
})
vim.api.nvim_create_autocmd("FileType", {
	desc = "用q关闭man窗口",
	pattern = "man",
	command = [[nnoremap <buffer><silent> q :quit<CR>]],
})

local cursorLineGroup = vim.api.nvim_create_augroup("CursorLineGroup", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
	desc = "仅在活动窗口显示光标线",
	group = cursorLineGroup,
	pattern = "*",
	command = "set cursorline",
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
	desc = "仅在活动窗口显示光标线",
	group = cursorLineGroup,
	pattern = "*",
	command = "set nocursorline",
})

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "复制文本同时高亮该文本",
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
})

-- 支持从ssh复制/粘贴到本地
local function write(osc52)
	local success = false
	if vim.fn.filewritable("/dev/fd/2") == 1 then
		success = vim.fn.writefile({ osc52 }, "/dev/fd/2", "b") == 0
	else
		success = vim.fn.chansend(vim.v.stderr, osc52) > 0
	end
	return success
end
vim.api.nvim_create_autocmd({ "TermRequest" }, {
	desc = "Handles OSC 52",
	callback = function(args)
		if args.data:match("\027]52;c;") then
			local to_copy = args.data:gsub("\027]52;c;", "")
			local osc52 = string.format("\27]52;c;%s\7", to_copy)
			if os.getenv("TMUX") or os.getenv("TERM"):match("^tmux") or os.getenv("TERM"):match("^screen") then
				osc52 = string.format("\27Ptmux;\27%s\27\\", osc52)
			end
			write(osc52)
		end
	end,
})

vim.api.nvim_create_autocmd("BufWinEnter", {
	group = vim.api.nvim_create_augroup("IrreplaceableWindows", { clear = true }),
	pattern = "*",
	callback = function()
		local filetypes = { "neo-tree" }
		local buftypes = { "nofile", "terminal" }
		if vim.tbl_contains(buftypes, vim.bo.buftype) and vim.tbl_contains(filetypes, vim.bo.filetype) then
			vim.cmd("set winfixbuf")
		end
	end,
})

vim.api.nvim_create_autocmd({ "CursorHold", "FileType" }, {
	desc = "Force commentstring to include spaces",
	group = vim.api.nvim_create_augroup("commentstring_spaces", { clear = true }),
	callback = function(args)
		local cs = vim.bo[args.buf].commentstring
		vim.bo[args.buf].commentstring = cs:gsub("(%S)%%s", "%1 %%s"):gsub("%%s(%S)", "%%s %1")
	end,
})

vim.api.nvim_create_user_command("BufferDelete", function()
	---@diagnostic disable-next-line: missing-parameter
	local file_exists = vim.fn.filereadable(vim.fn.expand("%p"))
	local modified = vim.api.nvim_buf_get_option(0, "modified")
	if file_exists == 0 and modified then
		local user_choice = vim.fn.input("The file is not saved, whether to force delete? Press enter or input [y/n]:")
		if user_choice == "y" or string.len(user_choice) == 0 then
			vim.cmd("bd!")
		end
		return
	end
	local force = not vim.bo.buflisted or vim.bo.buftype == "nofile"
	vim.cmd(force and "bd!" or string.format("bp | bd! %s", vim.api.nvim_get_current_buf()))
end, { desc = "Delete the current Buffer while maintaining the window layout" })

vim.api.nvim_create_user_command("ToggleQuickfix", function()
	local windows = vim.fn.getwininfo()
	local quickfixOpen = false
	for _, win in ipairs(windows) do
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
	local locationList = vim.fn.getloclist(0)
	if #locationList == 0 then
		vim.api.nvim_err_write("当前没有loclist窗口\n")
		return
	end
	local windows = vim.fn.getwininfo()
	local locationListOpen = false
	for _, win in ipairs(windows) do
		if win.loclist == 1 then
			locationListOpen = true
			break
		end
	end
	if locationListOpen then
		vim.cmd("lclose")
	else
		vim.cmd("lopen")
	end
end, { desc = "Toggle Location List" })
