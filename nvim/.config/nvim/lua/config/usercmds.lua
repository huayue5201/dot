-- ===========================
-- 判断窗口是否打开
-- ===========================
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win[win_type] == 1 then
			return true -- 如果指定类型窗口打开，返回 true
		end
	end
	return false -- 如果未找到指定类型窗口，返回 false
end

-- ===========================
-- 切换 Quickfix 窗口
-- ===========================
vim.api.nvim_create_user_command("ToggleQuickfix", function()
	if is_window_open("quickfix") then
		vim.cmd("cclose") -- 如果 Quickfix 窗口已打开，关闭该窗口
	else
		vim.cmd("copen") -- 如果 Quickfix 窗口未打开，打开该窗口
	end
end, { desc = "切换 Quickfix 窗口" })

-- ===========================
-- 切换 Location List 窗口
-- ===========================
vim.api.nvim_create_user_command("ToggleLoclist", function()
	if is_window_open("loclist") then
		vim.cmd("lclose") -- 如果 Location List 窗口已打开，关闭该窗口
	else
		local locationList = vim.fn.getloclist(0)
		if #locationList > 0 then
			vim.cmd("lopen") -- 如果有可用的 Location List，打开该窗口
		else
			vim.notify("当前没有 loclist 可用", vim.log.levels.WARN) -- 如果没有可用的 Location List，发出警告
		end
	end
end, { desc = "切换 Location List" })

-- ===========================
-- 查看 vim 信息
-- ===========================
vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim" -- 设置缓冲区为 vim 文件类型
	local messages = vim.split(vim.fn.execute("messages", "silent"), "\n")
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages) -- 将 Vim 消息填充到缓冲区
	vim.cmd("belowright split") -- 在下方打开一个新的窗口
	vim.api.nvim_win_set_buf(0, scratch_buffer) -- 将新窗口的缓冲区设置为刚才创建的缓冲区
	vim.opt_local.wrap = true -- 启用行自动换行
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe" -- 关闭缓冲区时自动删除该缓冲区
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer }) -- 设置快捷键 q 来关闭窗口
end, {})

-- ===========================
-- 删除标记相关命令
-- ===========================

-- ===========================
-- 删除指定标记
-- ===========================
vim.api.nvim_create_user_command("DelMarks", function()
	local marks_output = vim.fn.execute("marks")
	vim.notify("当前标记:\n" .. marks_output, vim.log.levels.INFO) -- 显示当前所有标记
	local mark = vim.fn.input("输入要删除的标记: ") -- 输入要删除的标记名称
	vim.cmd("redraw!") -- 重新绘制界面
	if mark ~= "" then
		vim.cmd("delmarks " .. mark) -- 删除指定标记
		vim.notify("已删除标记: " .. mark) -- 提示已删除标记
	else
		vim.api.nvim_echo({ { "未输入标记，操作已中止.", "Error" } }, true, {}) -- 如果未输入标记，提示错误信息
	end
end, { desc = "删除指定标记" })

-- ===========================
-- 删除所有标记或当前行标记（交互式选择）
-- ===========================
vim.api.nvim_create_user_command("DelMarksInteractive", function()
	local choice = vim.fn.input("1: 删除所有标记, 2: 删除当前行标记: ") -- 选择删除方式
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
			vim.notify("已删除标记: " .. table.concat(deleted_marks, ", "), vim.log.levels.INFO) -- 提示已删除标记
		end
	end
	vim.cmd("redraw!") -- 重新绘制界面
	if choice == "1" then
		vim.cmd("delmarks a-z")
		vim.cmd("delmarks A-Z")
		vim.notify("所有标记已删除!", vim.log.levels.INFO) -- 删除所有标记
	elseif choice == "2" then
		delete_marks(true) -- 删除当前行标记
		delete_marks(false) -- 删除全局标记
	else
		vim.notify("无效的选择！", vim.log.levels.ERROR) -- 提示无效选择
	end
end, { desc = "删除标记（交互选择删除方式）" })

-- ===========================
-- 删除缓冲区命令
-- ===========================

-- ===========================
-- 删除缓冲区（关闭文件）
-- ===========================
vim.api.nvim_create_user_command("DeleteBuffer", function()
	local buflisted = vim.fn.getbufinfo({ buflisted = 1 })
	local cur_winnr, cur_bufnr = vim.fn.winnr(), vim.fn.bufnr()
	if #buflisted < 2 then
		vim.cmd("confirm qall") -- 如果只有一个缓冲区，退出所有缓冲区
		return
	end
	for _, winid in ipairs(vim.fn.getbufinfo(cur_bufnr)[1].windows) do
		vim.cmd(string.format("%d wincmd w", vim.fn.win_id2win(winid))) -- 切换到该窗口
		vim.cmd(cur_bufnr == buflisted[#buflisted].bufnr and "bp" or "bn") -- 切换到下一个或上一个缓冲区
	end
	vim.cmd(string.format("%d wincmd w", cur_winnr)) -- 切换回原来的窗口
	local is_terminal = vim.fn.getbufvar(cur_bufnr, "&buftype") == "terminal"
	vim.cmd(is_terminal and "bd! #" or "silent! confirm bd #") -- 如果是终端缓冲区，强制删除，否则确认删除
end, {})
