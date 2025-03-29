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
-- 高亮复制内容
-- ===========================
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		vim.highlight.on_yank({ timeout = 330 }) -- 高亮复制的内容
	end,
})

-- ===========================
-- 复制时保持光标位置
-- ===========================
local cursorPreYank
-- 保存普通模式（Normal）和可视模式（Visual）下的复制前光标位置
vim.keymap.set({ "n", "x" }, "y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y"
end, { expr = true })
-- 保存 `Y` 按键的光标位置并复制当前行到行尾
vim.keymap.set("n", "Y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y$"
end, { expr = true })
-- 复制后恢复光标位置
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		if vim.v.event.operator == "y" and cursorPreYank then
			vim.api.nvim_win_set_cursor(0, cursorPreYank)
			cursorPreYank = nil -- 重置，避免下次错误
		end
	end,
})

-- 自动延迟同步到系统剪贴板，避免vim.opt.clipboard = "unnamedplus"带来的性能问题
vim.api.nvim_create_autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		local reg_type = vim.fn.getregtype('"')
		-- 如果是普通复制操作（不是通过系统剪贴板触发）
		if reg_type ~= "+" then
			local clipboard_content = vim.fn.getreg('"')
			if clipboard_content ~= "" then
				vim.defer_fn(function()
					vim.fn.setreg("+", clipboard_content)
				end, 20)
			end
		end
	end,
})

-- -- 错误捕捉模块
-- vim.api.nvim_create_autocmd("VimLeave", {
-- 	callback = function()
-- 		local log_file = vim.fn.stdpath("config") .. "/logfile.txt"
-- 		local file = io.open(log_file, "a")
-- 		if file then
-- 			local err = vim.fn.execute("messages") -- 获取错误信息
-- 			file:write("Neovim closed with the following errors:\n")
-- 			file:write(err)
-- 			file:write("\n\n")
-- 			file:close()
-- 		end
-- 	end,
-- })

-- ===========================
-- 自动识别项目根目录
-- ===========================
-- vim.api.nvim_create_autocmd("BufEnter", {
-- 	callback = function(ctx)
-- 		local root = vim.fs.root(ctx.file, { ".git", "Makefile", "cargo.toml" }) -- 修正参数错误
-- 		if root then
-- 			vim.fn.chdir(root)
-- 		end
-- 	end,
-- })

-- ===========================
-- 用 q 关闭窗口或删除缓冲区
-- ===========================
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "用 q 关闭窗口或删除缓冲区",
	pattern = "*",
	callback = function()
		local close_commands = require("config.utils").close_commands
		local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype -- 优先 filetype，否则 buftype
		local command = close_commands[current_type]
		if command then
			vim.api.nvim_buf_set_keymap(0, "n", "q", command, { noremap = true, silent = true })
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
		local filetypes = { "dap-float", "floggraph", "fugitive", "NvimTree", "grug-far", "toggleterm" }
		local buftypes = { "nofile", "terminal", "acwrite" }
		-- 判断当前窗口是否为不可替换窗口类型
		if vim.tbl_contains(buftypes, vim.bo.buftype) and vim.tbl_contains(filetypes, vim.bo.filetype) then
			vim.wo.winfixbuf = true
		end
	end,
})

local function delete_qf_items()
	local is_qf = vim.fn.getwininfo(vim.fn.win_getid())[1].quickfix == 1
	local qflist = is_qf and vim.fn.getqflist() or vim.fn.getloclist(0)
	local mode = vim.api.nvim_get_mode().mode
	local start_idx, count
	if mode == "n" then
		-- Normal 模式：删除当前行
		start_idx = vim.fn.line(".")
		count = vim.v.count > 0 and vim.v.count or 1
	else
		-- Visual 模式：获取选区起点和终点
		local v_start_idx = vim.fn.line("v")
		local v_end_idx = vim.fn.line(".")
		start_idx = math.min(v_start_idx, v_end_idx)
		count = math.abs(v_end_idx - v_start_idx) + 1
		-- 退出 Visual 模式
		vim.cmd("normal! <esc>")
	end
	-- 🛠 避免超出范围的删除
	if start_idx < 1 or start_idx > #qflist then
		return
	end
	-- 🛠 批量删除
	for _ = 1, count do
		if start_idx <= #qflist then
			table.remove(qflist, start_idx)
		end
	end
	-- 更新 Quickfix 或 Location List
	if is_qf then
		vim.fn.setqflist(qflist, "r")
	else
		vim.fn.setloclist(0, qflist, "r")
	end
	-- 🛠 删除最后一个条目时，调整光标位置
	local new_pos = math.min(start_idx, #qflist)
	if new_pos > 0 then
		vim.fn.cursor(new_pos, 1)
	end
end
-- 🔹 Quickfix 窗口的快捷键绑定
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
	pattern = "qf",
	callback = function()
		-- 让 Quickfix 不显示在 `:buffers` 列表中
		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })
		-- 按 `<ESC>` 关闭 Quickfix 窗口
		vim.keymap.set("n", "<ESC>", "<CMD>cclose<CR>", { buffer = true, silent = true })
		-- `dd` 删除单个 Quickfix 条目
		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true })
		-- `d` 删除选中的 Quickfix 条目（可视模式）
		vim.keymap.set("x", "d", delete_qf_items, { buffer = true })
	end,
	desc = "Quickfix tweaks",
})
