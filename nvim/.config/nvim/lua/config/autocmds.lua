-- ===========================
-- 清理尾部空白字符
-- ===========================
vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "保存文件时移除末尾的空白字符",
	group = vim.api.nvim_create_augroup("cleanSpace", { clear = true }),
	pattern = "*",
	command = "%s/\\s\\+$//e", -- 在保存文件前，删除末尾的空白字符
})

-- ===========================
-- 记住最后的光标位置
-- ===========================
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"') -- 获取最后的光标位置
		local lcount = vim.api.nvim_buf_line_count(0) -- 获取缓冲区的总行数
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark) -- 设置光标为最后保存的位置
		end
	end,
})

-- ===========================
-- 禁止换行时延续注释符号
-- ===========================
vim.api.nvim_create_autocmd("FileType", {
	desc = "换行时不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" }) -- 移除 'o' 和 'r' 格式选项，防止换行时继续注释符号
	end,
})

-- ===========================
-- 高亮复制内容（默认不限制字符数）
-- ===========================
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank() -- 高亮复制的内容
	end,
})

-- ===========================
-- 可视模式下复制时固定光标位置
-- ===========================
local cursorPreYank
vim.keymap.set({ "n", "x" }, "y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0) -- 复制前记录光标位置
	return "y"
end, { expr = true })

vim.keymap.set({ "x" }, "Y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y$" -- 在可视模式下复制时固定光标位置
end, { expr = true })

vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		if vim.v.event.operator == "y" and cursorPreYank then
			vim.api.nvim_win_set_cursor(0, cursorPreYank) -- 复制后恢复光标位置
		end
	end,
})

-- ===========================
-- 用 q 关闭窗口或删除缓冲区
-- ===========================
vim.api.nvim_create_autocmd("FileType", {
	desc = "用 q 关闭窗口或删除缓冲区",
	pattern = "*",
	callback = function()
		-- 为特定文件类型设置 q 键关闭窗口或删除缓冲区
		local filetype_commands = {
			["help"] = ":close<CR>", -- 在 help 文件类型中，q 键关闭窗口
			["qf"] = ":close<CR>", -- 在 Quickfix 窗口中，q 键关闭窗口
			["checkhealth"] = ":close<CR>", -- 在 checkhealth 中，q 键关闭窗口
			["man"] = ":quit<CR>", -- 在 man 页中，q 键退出
			["grug-far"] = ":bdelete<CR>", -- 在 grug-far 文件类型中，q 键删除缓冲区
			["minideps-confirm"] = ":bdelete<cr>", -- 在 minideps-confirm 中，q 键删除缓冲区
			["toggleterm"] = ":close<CR>", -- 在 toggleterm 中，q 键关闭终端窗口
		}

		local current_filetype = vim.bo.filetype -- 获取当前文件类型
		local command = filetype_commands[current_filetype] -- 获取当前文件类型对应的命令
		if command then
			vim.api.nvim_buf_set_keymap(0, "n", "q", command, { noremap = true, silent = true }) -- 设置 q 键的命令
		end
	end,
})

-- ===========================
-- 窗口固定类容
-- ===========================
vim.api.nvim_create_augroup("IrrepLaceableWindows", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
	group = "IrrepLaceableWindows",
	pattern = "*",
	callback = function()
		-- 定义需要固定大小的窗口类型
		local filetypes = { "NvimTree", "grug-far", "toggleterm" }
		local buftypes = { "nofile", "terminal" }

		-- 判断当前窗口是否为不可替换窗口类型
		if vim.tbl_contains(buftypes, vim.bo.buftype) and vim.tbl_contains(filetypes, vim.bo.filetype) then
			vim.cmd("set winfixbuf") -- 固定窗口大小，防止被调整
		end
	end,
})

-- ===========================
-- LSP 进度通知
-- ===========================
-- vim.api.nvim_create_autocmd("LspProgress", {
--   ---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
--   callback = function(ev)
--     -- 定义用于展示进度的旋转符号
--     local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
--
--     -- 使用 vim.notify 显示 LSP 进度
--     vim.notify(vim.lsp.status(), "info", {
--       id = "lsp_progress",  -- 设置通知 ID，方便更新和清除
--       title = "LSP Progress",  -- 设置通知的标题
--       opts = function(notif)
--         -- 设置通知图标，如果 LSP 进度已完成则显示勾号，否则显示旋转符号
--         notif.icon = ev.data.params.value.kind == "end" and " "  -- 进度结束时显示勾号
--           or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]  -- 否则显示旋转符号
--       end,
--     })
--   end,
-- })
--
