-- 保存时自动格式化
-- vim.api.nvim_create_autocmd("LspAttach", {
-- 	desc = "保存时自动格式化",
-- 	group = vim.api.nvim_create_augroup("lsp", { clear = true }),
-- 	callback = function(args)
-- 		vim.api.nvim_create_autocmd("BufWritePre", {
-- 			buffer = args.buf,
-- 			callback = function()
-- 				vim.lsp.buf.format({ async = false, id = args.data.client_id })
-- 			end,
-- 		})
-- 	end,
-- })

-- 自动保存
vim.api.nvim_create_autocmd("FocusLost", {
	desc = "窗口切换时自动保存文件",
	group = vim.api.nvim_create_augroup("auto_save", { clear = true }),
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

-- 换行不要延续注释符号
vim.api.nvim_create_autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- grep功能优化
vim.cmd([[command! -nargs=+ Grep execute 'silent grep! <args>' | copen]])

-- 定义快速修复映射函数
local function QuickfixMapping()
	-- 使快速修复列表可修改
	vim.keymap.set("n", "<leader>u", ":set modifiable<CR>", { buffer = true })
	-- 在快速修复窗口保存更改
	vim.keymap.set("n", "<leader>o", ":cgetbuffer<CR>:cclose<CR>:copen<CR>", { buffer = true })
end

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("quickfix_group", { clear = true }),
	pattern = "qf",
	callback = QuickfixMapping,
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

-- 高亮复制文本
vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "复制文本同时高亮该文本",
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank()
	end,
})

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
	group = vim.api.nvim_create_augroup("IndentBlanklineBigFile", { clear = true }),
	pattern = "*",
	callback = function()
		-- 检查行数和文件大小
		local bufnr = vim.api.nvim_get_current_buf() -- 获取当前缓冲区编号
		local bufname = vim.api.nvim_buf_get_name(bufnr) -- 获取当前缓冲区的名称或路径
		local stat = vim.loop.fs_stat(bufname)
		if vim.api.nvim_buf_line_count(bufnr) > 20000 and (stat and stat.size or 0) > 100 * 1024 then
			vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
			vim.api.nvim_buf_set_option(bufnr, "syntax", "off")
			vim.api.nvim_buf_set_option(bufnr, "filetype", "off")
			vim.api.nvim_buf_set_option(bufnr, "undofile", false)
			vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
			vim.api.nvim_buf_set_option(bufnr, "loadplugins", false)
		end
	end,
})
