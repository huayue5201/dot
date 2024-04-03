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
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
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
	desc = "remember last cursor place",
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
