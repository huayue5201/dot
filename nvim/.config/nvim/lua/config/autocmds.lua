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

-- 合并高亮复制 & 光标恢复 & 剪贴板同步
vim.api.nvim_create_autocmd("TextYankPost", {
	pattern = "*",
	callback = function()
		-- ① 高亮复制的内容
		vim.hl.on_yank({ timeout = 330 })

		-- ② 恢复光标位置（仅限 `yank` 操作）
		if vim.v.event.operator == "y" and cursorPreYank then
			vim.api.nvim_win_set_cursor(0, cursorPreYank)
			cursorPreYank = nil
		end

		-- ③ 延迟同步到系统剪贴板，优化 `unnamedplus` 的性能
		local reg_type = vim.fn.getregtype('"')
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

-- local paths = {
-- 	vim.fn.stdpath("data") .. "/lazy/friendly-snippets/package.json",
-- 	vim.fn.expand("$MYVIMRC"):match("(.*[/\\])") .. "snippets/package.json",
-- }
-- local descs = { "FR", "USR" }
-- local sn_group = vim.api.nvim_create_augroup("SnippetServer", { clear = true })
-- vim.api.nvim_create_autocmd({ "InsertEnter" }, {
-- 	group = sn_group,
-- 	once = true,
-- 	callback = function()
-- 		require("config.snippet").snippet_handler(paths, vim.bo.filetype, descs)
-- 		vim.api.nvim_create_autocmd({ "BufEnter" }, {
-- 			group = sn_group,
-- 			callback = function()
-- 				require("config.snippet").snippet_handler(paths, vim.bo.filetype, descs)
-- 			end,
-- 			desc = "Handle LSP for buffer changes",
-- 		})
-- 	end,
-- })

vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("TreesitterFolds", { clear = true }),
	desc = "load treesitter folds later to copensate for async loading",
	callback = function(args)
		local bufnr = args.buf
		-- check if treesitter is available
		if pcall(vim.treesitter.start, bufnr) then
			vim.wo[0][0].foldmethod = "expr"
			vim.wo[0][0].foldexpr = "v:lua.vim.treesitter.foldexpr()"
		else
			vim.wo[0][0].foldmethod = "manual"
		end
	end,
})

vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "用 q 关闭窗口或删除缓冲区",
	pattern = "*",
	callback = function()
		local close_commands = require("config.utils").close_commands
		local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local command = close_commands[current_type]
		if command then
			local opts = { buffer = true, noremap = true, silent = true }
			if type(command) == "function" then
				vim.keymap.set("n", "q", command, opts)
			else
				vim.keymap.set("n", "q", function()
					vim.cmd(command)
				end, opts)
			end
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
