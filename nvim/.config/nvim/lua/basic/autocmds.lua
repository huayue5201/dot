local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- 延迟加载模块
-- autocmd("VimEnter", {
-- 	desc = "延迟加载模块",
-- 	group = augroup("lazyModule", { clear = true }),
-- 	callback = function()
-- 	end,
-- })

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

autocmd("FocusLost", {
	desc = "窗口切换时自动保存文件",
	group = augroup("autosave", { clear = true }),
	pattern = "*",
	callback = function()
		vim.cmd("silent! wa")
	end,
})

autocmd("BufWritePre", {
	desc = "保存文件时移除末尾的空白字符",
	group = augroup("cleanSpace", { clear = true }),
	pattern = "*",
	command = "%s/\\s\\+$//e",
})

autocmd({ "FileType", "BufEnter" }, {
	desc = "特定buffer内禁用状态列",
	callback = function()
		local special_filetypes = { "neo-tree", "aerial", "toggleterm", "qf", "help", "man" }
		if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
			vim.wo.statuscolumn = ""
		end
	end,
})

autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = augroup("LastPlace", { clear = true }),
	pattern = { "*" },
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

autocmd("FileType", {
	desc = "用q关闭窗口",
	pattern = { "help", "startuptime", "qf", "lspinfo", "checkhealth" },
	command = [[nnoremap <buffer><silent> q :close<CR>]],
})
autocmd("FileType", {
	desc = "用q关闭man窗口",
	pattern = "man",
	command = [[nnoremap <buffer><silent> q :quit<CR>]],
})

local cursorLineGroup = augroup("CursorLineGroup", { clear = true })
autocmd({ "InsertLeave", "WinEnter" }, {
	desc = "仅在活动窗口显示光标线",
	group = cursorLineGroup,
	pattern = "*",
	command = "set cursorline",
})
autocmd({ "InsertEnter", "WinLeave" }, {
	desc = "仅在活动窗口显示光标线",
	group = cursorLineGroup,
	pattern = "*",
	command = "set nocursorline",
})

-- autocmd("TextYankPost", {
-- 	desc = "复制文本同时高亮该文本",
-- 	group = augroup("YankHighlight", { clear = true }),
-- 	pattern = "*",
-- 	callback = function()
-- 		vim.highlight.on_yank()
-- 	end,
-- })

-- 自动关闭？/搜索匹配高亮
vim.on_key(function(char)
	if vim.fn.mode() == "n" then
		local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
		if vim.opt.hlsearch:get() ~= new_hlsearch then
			vim.opt.hlsearch = new_hlsearch
		end
	end
end, vim.api.nvim_create_namespace("auto_hlsearch"))

-- 递归创建缺失文件
vim.api.nvim_create_user_command("MakeDirectory", function()
	---@diagnostic disable-next-line: missing-parameter
	local path = vim.fn.expand("%")
	local dir = vim.fn.fnamemodify(path, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p")
	else
		vim.notify("Directory already exists", "WARN", { title = "Nvim" })
	end
end, { desc = "Create directory if it doesn't exist" })

-- 在保证窗口布局的情况下删除缓冲区
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
