-- 保存时自动格式化
vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("lsp", { clear = true }),
	desc = "保存时自动格式化",
	callback = function(args)
		vim.api.nvim_create_autocmd("BufWritePre", {
			buffer = args.buf,
			callback = function()
				vim.lsp.buf.format({ async = false, id = args.data.client_id })
			end,
		})
	end,
})

-- 自动保存
vim.api.nvim_create_autocmd("FocusLost", {
	group = vim.api.nvim_create_augroup("auto_save", { clear = true }),
	desc = "窗口切换时自动保存文件",
	pattern = "*",
	callback = function()
		vim.cmd("silent! wa")
	end,
})

-- 特定buffer内禁用状态列
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "特定buffer内禁用状态列",
	callback = function()
		local special_filetypes = { "NvimTree", "toggleterm", "aerial", "qf", "help", "man", "startuptime", "lspinfo" }
		if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
			vim.wo.statuscolumn = ""
		end
	end,
})

-- 光标自动定位到最后编辑的位置
local lastplace = vim.api.nvim_create_augroup("LastPlace", {})
vim.api.nvim_clear_autocmds({ group = lastplace })
vim.api.nvim_create_autocmd("BufReadPost", {
	group = lastplace,
	pattern = { "*" },
	desc = "记住最后的光标位置",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- 换行不要延续注释符号
vim.api.nvim_create_autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- 用q关闭窗口
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

-- 仅在活动窗口显示光标线
local cursorGrp = vim.api.nvim_create_augroup("CursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
	desc = "仅在活动窗口显示光标线",
	pattern = "*",
	command = "set cursorline",
	group = cursorGrp,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
	desc = "仅在活动窗口显示光标线",
	pattern = "*",
	command = "set nocursorline",
	group = cursorGrp,
})

--- 保存时删除所有尾随空格
local TrimWhiteSpaceGrp = vim.api.nvim_create_augroup("TrimWhiteSpaceGrp", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "保存时删除所有尾随空格",
	command = [[:%s/\s\+$//e]],
	group = TrimWhiteSpaceGrp,
})

-- 创建高亮组并添加 TextYankPost 自动命令
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "复制文本同时高亮该文本",
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})

-- 插入模式下TAB可以跳出()[]....
keymap("i", "<Tab>", function()
	local cursor = vim.api.nvim_win_get_cursor(0)
	local line = vim.api.nvim_get_current_line()
	local next_char = line:sub(cursor[2] + 1, cursor[2] + 1)
	if next_char == nil then
		return "<Tab>"
	end

	if not vim.tbl_contains({ '"', "'", ")", "]", "}", ">" }, next_char) then
		return "<Tab>"
	end

	return "<Right>"
end, { expr = true })

-- 自动关闭？/搜索匹配高亮
vim.on_key(function(char)
	if vim.fn.mode() == "n" then
		local new_hlsearch = vim.tbl_contains({ "<CR>", "n", "N", "*", "#", "?", "/" }, vim.fn.keytrans(char))
		if vim.opt.hlsearch:get() ~= new_hlsearch then
			vim.opt.hlsearch = new_hlsearch
		end
	end
end, vim.api.nvim_create_namespace("auto_hlsearch"))

-- 优化打开大文件性能
vim.api.nvim_create_autocmd("BufEnter", {
	group = vim.api.nvim_create_augroup("IndentBlanklineBigFile", {}),
	pattern = "*",
	callback = function()
		if vim.api.nvim_buf_line_count(0) > 20000 then
			local bufnr = 0 -- 当前缓冲区的编号
			vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
			vim.api.nvim_buf_set_option(bufnr, "syntax", "off")
			vim.api.nvim_buf_set_option(bufnr, "filetype", "off")
			vim.api.nvim_buf_set_option(bufnr, "undofile", false)
			vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
			vim.api.nvim_buf_set_option(bufnr, "loadplugins", false)
		end
	end,
})
