local autocmd = vim.api.nvim_create_autocmd
local augroup = vim.api.nvim_create_augroup

-- 延迟加载模块
-- autocmd("VimEnter", {
-- 	desc = "延迟加载模块",
-- 	group = augroup("lazyConfig", { clear = true }),
-- 	callback = function()
-- 	end,
-- })

-- 自动保存
autocmd("FocusLost", {
	desc = "窗口切换时自动保存文件",
	group = augroup("autosave", { clear = true }),
	pattern = "*",
	callback = function()
		vim.cmd("silent! wa")
	end,
})

-- 特定buffer内禁用状态列
autocmd({ "FileType", "BufEnter" }, {
	desc = "特定buffer内禁用状态列",
	callback = function()
		local special_filetypes = { "NvimTree", "toggleterm", "aerial", "qf", "help", "man", "startuptime", "lspinfo" }
		if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
			vim.wo.statuscolumn = ""
		end
	end,
})

-- 光标自动定位到最后编辑的位置
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

-- 换行不要延续注释符号
autocmd("FileType", {
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

autocmd("FileType", {
	group = augroup("quickfix_group", { clear = true }),
	pattern = "qf",
	callback = QuickfixMapping,
})

-- 用q关闭窗口
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

-- 仅在活动窗口显示光标线
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

-- 高亮复制文本
autocmd("TextYankPost", {
	desc = "复制文本同时高亮该文本",
	group = augroup("YankHighlight", { clear = true }),
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
autocmd("BufEnter", {
	group = augroup("IndentBlanklineBigFile", { clear = true }),
	pattern = "*",
	callback = function()
		-- 获取当前缓冲区信息
		local bufnr = vim.api.nvim_get_current_buf() -- 获取当前缓冲区编号
		local bufname = vim.api.nvim_buf_get_name(bufnr) -- 获取当前缓冲区的名称或路径
		local stat = vim.loop.fs_stat(bufname) -- 获取文件的状态信息

		local line_count = vim.api.nvim_buf_line_count(bufnr)
		local file_type = vim.api.nvim_buf_get_option(bufnr, "filetype")

		if line_count > 10000 or (stat and stat.size or 0) > 100 * 1024 then
			-- 大文件设置
			vim.api.nvim_buf_set_option(bufnr, "syntax", "off")
			vim.api.nvim_buf_set_option(bufnr, "foldmethod", "manual")
			vim.api.nvim_buf_set_option(bufnr, "filetype", "off")
			vim.api.nvim_buf_set_option(bufnr, "undofile", false)
			vim.api.nvim_buf_set_option(bufnr, "swapfile", false)
			vim.api.nvim_buf_set_option(bufnr, "loadplugins", false)
		end
		-- 匹配文件类型并执行相应的操作
		local disable_highlight_files = { "log", "txt", "md" } -- 需要禁用的文件类型列表
		if vim.tbl_contains(disable_highlight_files, file_type) or line_count > 5000 then
			vim.cmd("DisableHL")
		end
	end,
})
