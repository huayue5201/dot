-- 保存时自动格式话
-- 1
-- vim.api.nvim_create_autocmd("LspAttach", {
-- 	group = vim.api.nvim_create_augroup("lsp", { clear = true }),
-- 	callback = function(args)
-- 		-- 2
-- 		vim.api.nvim_create_autocmd("BufWritePre", {
-- 			-- 3
-- 			buffer = args.buf,
-- 			callback = function()
-- 				-- 4 + 5
-- 				vim.lsp.buf.format({ async = false, id = args.data.client_id })
-- 			end,
-- 		})
-- 	end,
-- })

-- 特定buffer内禁用状态列
vim.api.nvim_create_autocmd("BufEnter", {
	callback = function()
		local special_filetypes = { "NvimTree", "terminal", "qf", "help", "man", "startuptime", "lspinfo" }
		if vim.tbl_contains(special_filetypes, vim.bo.filetype) then
			vim.wo.statuscolumn = ""
		end
	end,
})

-- 光标自动定位到最后编辑的位置
-- 在 BufReadPost 事件后执行命令，将光标定位到上次编辑的位置
vim.api.nvim_create_autocmd("BufReadPost", {
	command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]],
})

-- 换行不要延续注释符号
vim.api.nvim_create_autocmd("FileType", {
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- 用q关闭窗口
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "help", "startuptime", "qf", "lspinfo", "checkhealth" },
	command = [[nnoremap <buffer><silent> q :close<CR>]],
})
vim.api.nvim_create_autocmd("FileType", {
	pattern = "man",
	command = [[nnoremap <buffer><silent> q :quit<CR>]],
})

-- 仅在活动窗口显示光标线
local cursorGrp = vim.api.nvim_create_augroup("CursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
	pattern = "*",
	command = "set cursorline",
	group = cursorGrp,
})
vim.api.nvim_create_autocmd({ "InsertEnter", "WinLeave" }, {
	pattern = "*",
	command = "set nocursorline",
	group = cursorGrp,
})

--- 保存时删除所有尾随空格
local TrimWhiteSpaceGrp = vim.api.nvim_create_augroup("TrimWhiteSpaceGrp", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
	command = [[:%s/\s\+$//e]],
	group = TrimWhiteSpaceGrp,
})

-- 创建高亮组并添加 TextYankPost 自动命令
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		vim.highlight.on_yank()
	end,
	group = highlight_group,
	pattern = "*",
})
