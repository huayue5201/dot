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
-- 切换 Quickfix 和 Location List 窗口
-- ===========================
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win[win_type] == 1 then
			return true -- 如果指定类型窗口打开，返回 true
		end
	end
	return false -- 如果未找到指定类型窗口，返回 false
end
-- 创建一个切换窗口的通用函数
vim.api.nvim_create_user_command("Toggle", function(opts)
	local win_type = opts.fargs[1] or "quickfix"
	if win_type == "quickfix" then
		if is_window_open("quickfix") then
			vim.cmd("cclose") -- 如果 Quickfix 窗口已打开，关闭该窗口
		else
			vim.cmd("copen") -- 如果 Quickfix 窗口未打开，打开该窗口
		end
	elseif win_type == "loclist" then
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
	end
end, { desc = "切换窗口", nargs = "?" })

-- ===========================
-- 关闭缓冲
-- ===========================
vim.api.nvim_create_user_command("DeleteBuffer", function()
	local fn = vim.fn
	local cmd = vim.cmd
	-- 获取所有列出的缓冲区
	local buflisted = fn.getbufinfo({ buflisted = 1 })
	-- 获取当前窗口和缓冲区的编号
	local cur_winnr, cur_bufnr = fn.winnr(), fn.bufnr()
	-- 获取当前窗口的布局信息
	local layout = fn.winlayout()
	-- 如果是分屏，直接退出缓冲
	if layout[1] ~= "leaf" then
		cmd("bd")
		return
	end
	-- 如果缓冲区数目少于 2，使用 confirm 来确认退出
	if #buflisted < 2 then
		cmd("confirm qall")
		return
	end
	-- 遍历当前缓冲区在所有窗口的显示情况
	for _, winid in ipairs(fn.getbufinfo(cur_bufnr)[1].windows) do
		-- 切换到当前缓冲区所在的窗口
		cmd(string.format("%d wincmd w", fn.win_id2win(winid)))
		-- 如果是最后一个缓冲区，切换到前一个缓冲区，否则切换到下一个缓冲区
		cmd(cur_bufnr == buflisted[#buflisted].bufnr and "bp" or "bn")
	end
	-- 切换回原始窗口
	cmd(string.format("%d wincmd w", cur_winnr))
	-- 判断当前缓冲区是否是一个终端缓冲区
	local is_terminal = fn.getbufvar(cur_bufnr, "&buftype") == "terminal"
	-- 如果是终端缓冲区，强制删除；否则，使用 confirm 进行确认删除
	cmd(is_terminal and "bd! #" or "silent! confirm bd #")
end, {
	desc = "Delete the current buffer with additional checks for unsaved changes and window management",
	nargs = 0, -- 不需要参数
})
