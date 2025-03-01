-- ===========================
-- 自动命令（Autocommands）
-- ===========================

-- 清理尾部空白字符
vim.api.nvim_create_autocmd("BufWritePre", {
	desc = "保存文件时移除末尾的空白字符",
	group = vim.api.nvim_create_augroup("cleanSpace", { clear = true }),
	pattern = "*",
	command = "%s/\\s\\+$//e",
})

-- 记住最后的光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "记住最后的光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lcount = vim.api.nvim_buf_line_count(0)
		if mark[1] > 0 and mark[1] <= lcount then
			pcall(vim.api.nvim_win_set_cursor, 0, mark)
		end
	end,
})

-- 禁止换行时延续注释符号
vim.api.nvim_create_autocmd("FileType", {
	desc = "换行不要延续注释符号",
	pattern = "*",
	callback = function()
		vim.opt.formatoptions:remove({ "o", "r" })
	end,
})

-- 高亮复制内容（默认不限制字符数）
vim.api.nvim_create_autocmd("TextYankPost", {
	group = vim.api.nvim_create_augroup("YankHighlight", { clear = true }),
	pattern = "*",
	callback = function()
		if #vim.v.event.regcontents > 0 then
			vim.highlight.on_yank()
		end
	end,
})

-- 可视模式下复制时固定光标位置
local cursorPreYank
vim.keymap.set({ "n", "x" }, "y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y"
end, { expr = true })
vim.keymap.set({ "x" }, "Y", function()
	cursorPreYank = vim.api.nvim_win_get_cursor(0)
	return "y$"
end, { expr = true })
vim.api.nvim_create_autocmd("TextYankPost", {
	callback = function()
		if vim.v.event.operator == "y" and cursorPreYank then
			vim.api.nvim_win_set_cursor(0, cursorPreYank)
		end
	end,
})

-- ===========================
-- 文件类型特定的映射
-- ===========================

-- 用 q 关闭窗口或删除缓冲区
vim.api.nvim_create_autocmd("FileType", {
	desc = "用 q 关闭窗口或删除缓冲区",
	pattern = "*",
	callback = function()
		local filetype_commands = {
			["help"] = ":close<CR>",
			["qf"] = ":close<CR>",
			["checkhealth"] = ":close<CR>",
			["man"] = ":quit<CR>",
			["grug-far"] = ":bdelete<CR>",
			["minideps-confirm"] = ":bdelete<cr>",
			["toggleterm"] = ":close<CR>",
		}
		local current_filetype = vim.bo.filetype
		local command = filetype_commands[current_filetype]
		if command then
			vim.api.nvim_buf_set_keymap(0, "n", "q", command, { noremap = true, silent = true })
		end
	end,
})

-- ===========================
-- 窗口管理（自动命令和自定义命令）
-- ===========================

-- 窗口大小固定（防止不可替换窗口被调整大小）
vim.api.nvim_create_augroup("IrrepLaceableWindows", { clear = true })
vim.api.nvim_create_autocmd("BufWinEnter", {
	group = "IrrepLaceableWindows",
	pattern = "*",
	callback = function()
		local filetypes = { "NvimTree", "grug-far", "toggleterm" }
		local buftypes = { "nofile", "terminal" }
		if vim.tbl_contains(buftypes, vim.bo.buftype) and vim.tbl_contains(filetypes, vim.bo.filetype) then
			vim.cmd("set winfixbuf")
		end
	end,
})

-- 判断窗口是否打开
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win[win_type] == 1 then
			return true
		end
	end
	return false
end

-- 切换 Quickfix 窗口
vim.api.nvim_create_user_command("ToggleQuickfix", function()
	if is_window_open("quickfix") then
		vim.cmd("cclose")
	else
		vim.cmd("copen")
	end
end, { desc = "切换 Quickfix 窗口" })

-- 切换 Location List 窗口
vim.api.nvim_create_user_command("ToggleLoclist", function()
	if is_window_open("loclist") then
		vim.cmd("lclose")
	else
		local locationList = vim.fn.getloclist(0)
		if #locationList > 0 then
			vim.cmd("lopen")
		else
			vim.notify("当前没有 loclist 可用", vim.log.levels.WARN)
		end
	end
end, { desc = "切换 Location List" })

-- 查看 vim 信息
vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim"
	local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages)
	vim.cmd("belowright split")
	vim.api.nvim_win_set_buf(0, scratch_buffer)
	vim.opt_local.wrap = true
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe"
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer })
end, {})

-- ===========================
-- 删除标记相关命令
-- ===========================

-- 删除指定标记
vim.api.nvim_create_user_command("DelMarks", function()
	local marks_output = vim.fn.execute("marks")
	vim.notify("当前标记:\n" .. marks_output, vim.log.levels.INFO)
	local mark = vim.fn.input("输入要删除的标记: ")
	vim.cmd("redraw!")
	if mark ~= "" then
		vim.cmd("delmarks " .. mark)
		vim.notify("已删除标记: " .. mark)
	else
		vim.api.nvim_echo({ { "未输入标记，操作已中止.", "Error" } }, true, {})
	end
end, { desc = "删除指定标记" })

-- 删除所有标记或当前行标记（交互式选择）
vim.api.nvim_create_user_command("DelMarksInteractive", function()
	local choice = vim.fn.input("1: 删除所有标记, 2: 删除当前行标记: ")
	-- 删除标记的辅助函数
	local function delete_marks(is_local)
		local marks = is_local and vim.fn.getmarklist(vim.api.nvim_get_current_buf()) or vim.fn.getmarklist()
		local deleted_marks = {}
		for _, mark in ipairs(marks) do
			local mark_name = string.sub(mark.mark, 2, 2)
			if
				(is_local and mark.pos[2] == vim.fn.line(".") and string.match(mark.mark, "'[a-z]"))
				or (not is_local and string.match(mark.mark, "'[A-Z]"))
			then
				-- 删除标记
				if is_local then
					vim.api.nvim_buf_del_mark(vim.api.nvim_get_current_buf(), mark_name)
				else
					vim.api.nvim_del_mark(mark_name)
				end
				table.insert(deleted_marks, mark_name)
			end
		end
		if #deleted_marks > 0 then
			vim.notify("已删除标记: " .. table.concat(deleted_marks, ", "), vim.log.levels.INFO)
		end
	end
	vim.cmd("redraw!")
	if choice == "1" then
		vim.cmd("delmarks a-z")
		vim.cmd("delmarks A-Z")
		vim.notify("所有标记已删除!", vim.log.levels.INFO)
	elseif choice == "2" then
		delete_marks(true)
		delete_marks(false)
	else
		vim.notify("无效的选择！", vim.log.levels.ERROR)
	end
end, { desc = "删除标记（交互选择删除方式）" })

-- ===========================
-- 删除缓冲区命令
-- ===========================

-- 删除缓冲区（关闭文件）
vim.api.nvim_create_user_command("DeleteBuffer", function()
	local buflisted = vim.fn.getbufinfo({ buflisted = 1 })
	local cur_winnr, cur_bufnr = vim.fn.winnr(), vim.fn.bufnr()
	if #buflisted < 2 then
		vim.cmd("confirm qall")
		return
	end
	for _, winid in ipairs(vim.fn.getbufinfo(cur_bufnr)[1].windows) do
		vim.cmd(string.format("%d wincmd w", vim.fn.win_id2win(winid)))
		vim.cmd(cur_bufnr == buflisted[#buflisted].bufnr and "bp" or "bn")
	end
	vim.cmd(string.format("%d wincmd w", cur_winnr))
	local is_terminal = vim.fn.getbufvar(cur_bufnr, "&buftype") == "terminal"
	vim.cmd(is_terminal and "bd! #" or "silent! confirm bd #")
end, {})

-- vim.api.nvim_create_autocmd("LspProgress", {
-- 	---@param ev {data: {client_id: integer, params: lsp.ProgressParams}}
-- 	callback = function(ev)
-- 		local spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }
-- 		vim.notify(vim.lsp.status(), "info", {
-- 			id = "lsp_progress",
-- 			title = "LSP Progress",
-- 			opts = function(notif)
-- 				notif.icon = ev.data.params.value.kind == "end" and " "
-- 					or spinner[math.floor(vim.uv.hrtime() / (1e6 * 80)) % #spinner + 1]
-- 			end,
-- 		})
-- 	end,
-- })
