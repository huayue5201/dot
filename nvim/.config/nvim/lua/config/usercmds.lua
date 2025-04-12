vim.api.nvim_create_user_command("Messages", function()
	local raw_messages = vim.fn.execute("messages", "silent")
	local messages = {}
	local function add_message(msg_block)
		if #msg_block > 0 then
			local timestamp = os.date("%Y-%m-%d %H:%M:%S")
			table.insert(messages, "=== [" .. timestamp .. "] ===")
			vim.list_extend(messages, msg_block)
			table.insert(messages, "")
		end
	end
	local current_message = {}
	for line in raw_messages:gmatch("[^\r\n]+") do
		if line:match("^%s*$") then
			goto continue
		end
		if #current_message > 0 and (line:match(":%d+: in function <") or line:match(" written$")) then
			add_message(current_message)
			current_message = {}
		end
		table.insert(current_message, line)
		::continue::
	end
	add_message(current_message)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, messages)
	local width = math.floor(vim.o.columns * 0.8)
	local height = math.min(#messages + 2, math.floor(vim.o.lines * 0.4))
	local opts = {
		relative = "editor",
		width = width,
		height = height,
		col = math.floor((vim.o.columns - width) / 2),
		row = vim.o.lines - height - 2, -- 固定到底部，避免遮挡 command line
		style = "minimal",
		border = "rounded",
		title = "Messages",
		title_pos = "center",
	}
	local win = vim.api.nvim_open_win(buf, true, opts)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].filetype = "vim"
	vim.bo[buf].modifiable = false
	vim.api.nvim_set_option_value("wrap", true, { win = win })
	-- 退出快捷键
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = buf, silent = true })
	vim.keymap.set("n", "<Esc>", "<cmd>close<CR>", { buffer = buf, silent = true })
	-- 高亮错误
	vim.api.nvim_buf_call(buf, function()
		vim.cmd([[
      syntax match ErrorMsg /^E\d\+:.\+$/
      highlight link ErrorMsg Error
    ]])
	end)
	-- 自动清除
	vim.api.nvim_create_autocmd("WinClosed", {
		pattern = tostring(win),
		once = true,
		callback = function()
			if vim.api.nvim_buf_is_valid(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
			end
		end,
	})
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
