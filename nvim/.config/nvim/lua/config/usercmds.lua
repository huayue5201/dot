vim.api.nvim_create_user_command("Messages", function()
	local scratch_buffer = vim.api.nvim_create_buf(false, true)
	vim.bo[scratch_buffer].filetype = "vim"
	local raw_messages = vim.fn.execute("messages", "silent")
	local messages = {}
	-- 添加时间戳到每个消息块的顶部
	local function add_message(msg_block)
		if #msg_block > 0 then
			local timestamp = os.date("%Y-%m-%d %H:%M:%S")
			-- 在消息块的开头添加时间戳
			table.insert(messages, "=== [" .. timestamp .. "] ===")
			for _, line in ipairs(msg_block) do
				table.insert(messages, line)
			end
			table.insert(messages, "") -- 添加空行分隔
		end
	end
	local current_message = {}
	for line in raw_messages:gmatch("[^\r\n]+") do
		if line:match("^%s*$") then
			goto continue -- 忽略空行
		end
		-- 遇到典型的 "文件写入" 或 "函数调用堆栈" 需要分隔消息
		if #current_message > 0 and (line:match(":%d+: in function <") or line:match(" written$")) then
			add_message(current_message)
			current_message = {}
		end
		table.insert(current_message, line)
		::continue::
	end
	-- 处理最后一条消息
	add_message(current_message)
	-- 确保所有消息被完整添加
	vim.api.nvim_buf_set_text(scratch_buffer, 0, 0, 0, 0, messages)
	-- 打开窗口
	vim.cmd("belowright split")
	vim.api.nvim_win_set_buf(0, scratch_buffer)
	-- 确保自动换行
	vim.opt_local.wrap = true
	vim.bo.buflisted = false
	vim.bo.bufhidden = "wipe"
	-- 退出快捷键
	vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buffer })
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

-- vim.api.nvim_create_user_command("DeleteBuffer", function()
-- 	local close_commands = require("config.utils").close_commands
-- 	local buflisted = vim.fn.getbufinfo({ buflisted = 1 })
-- 	local cur_winnr, cur_bufnr = vim.fn.winnr(), vim.fn.bufnr()
-- 	local layout = vim.fn.winlayout()
-- 	local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
-- 	local command = close_commands[current_type] or "bd"
-- 	-- 执行关闭命令
-- 	if type(command) == "function" then
-- 		command()
-- 		return
-- 	end
-- 	-- 处理分屏窗口，避免冗余判断
-- 	if layout[1] ~= "leaf" then
-- 		vim.cmd("bd")
-- 		return
-- 	end
-- 	-- 如果当前 buffer 是最后一个 listed buffer，提示并返回
-- 	if #buflisted <= 1 then
-- 		print("无法关闭最后一个 buffer！")
-- 		return
-- 	end
-- 	-- 直接检查当前缓冲区位置
-- 	local current_index = 0
-- 	for i, buf in ipairs(buflisted) do
-- 		if buf.bufnr == cur_bufnr then
-- 			current_index = i
-- 			break
-- 		end
-- 	end
-- 	-- 切换到前一个或下一个缓冲区
-- 	vim.cmd(current_index > 1 and "bp" or "bn")
-- 	-- 切换回原始窗口
-- 	vim.cmd(string.format("%d wincmd w", cur_winnr))
-- 	-- 强制处理终端缓冲区的关闭
-- 	local is_terminal = vim.bo.buftype == "terminal" or vim.bo.filetype == "toggleterm"
-- 	if is_terminal then
-- 		vim.cmd("bd! #") -- 强制删除 terminal 类型的缓冲区
-- 	else
-- 		vim.cmd("silent! confirm bd #") -- 处理其他类型的缓冲区，避免两次提示
-- 	end
-- end, {
-- 	desc = "删除当前缓冲区，并进行窗口管理的额外检查",
-- 	nargs = 0, -- 不需要参数
-- })

if vim.fn.executable("rg") == 1 then
	vim.api.nvim_create_user_command("RgFiles", function(opts)
		local pattern = opts.args
		if pattern == "" then
			return vim.notify("No search pattern provided", vim.log.levels.WARN)
		end
		-- Construct the original piped command
		local cmd = string.format(
			"rg --files --color=never --hidden --glob '!*.git' | rg --smart-case --color=never '%s'",
			pattern
		)
		-- Initialize pipes and result storage
		local stdout = vim.uv.new_pipe(false)
		local stderr = vim.uv.new_pipe(false)
		local results = {}
		-- Callback function when the process exits
		local function on_exit(code, signal)
			-- Nil checks before calling methods
			if stdout then
				stdout:read_stop()
				stdout:close()
			end
			if stderr then
				stderr:read_stop()
				stderr:close()
			end
			vim.schedule(function()
				if code > 1 then
					vim.notify("Error running rg: exit code " .. code, vim.log.levels.WARN)
					return
				end
				if #results == 0 then
					if code == 1 then
						vim.notify("No matches found", vim.log.levels.INFO)
					else
						vim.notify("No matches found or an error occurred", vim.log.levels.WARN)
					end
					return
				end
				-- Prepare the quickfix list
				local qf_list = {}
				for _, line in ipairs(results) do
					table.insert(qf_list, { filename = line })
				end
				-- Set the quickfix list with the results
				vim.fn.setqflist(qf_list, "r")
				-- Set additional options like the title
				vim.fn.setqflist({}, "a", { title = string.format("Results for pattern: '%s'", pattern) })
				-- Open the quickfix window
				vim.cmd("copen")
				-- Resize the quickfix window if there are fewer than 10 results
				if #results < 10 then
					vim.cmd("resize " .. #results)
				end
			end)
			if code > 1 then
				vim.schedule(function()
					vim.notify("Error running rg: exit code " .. code, vim.log.levels.WARN)
				end)
			end
		end
		-- Spawn a shell to run the piped command
		local handle
		handle = vim.uv.spawn(tostring(vim.opt.shell._value), {
			args = { "-c", cmd },
			stdio = { nil, stdout, stderr },
		}, function(code, signal)
			handle:close()
			on_exit(code, signal)
		end)
		-- Read stdout and nil check before calling methods
		if not stdout then
			return
		end
		stdout:read_start(function(err, data)
			assert(not err, err)
			if data then
				for line in data:gmatch("[^\r\n]+") do
					table.insert(results, line)
				end
			end
		end)
		-- Read stderr and nil check before calling methods
		if not stderr then
			return
		end
		stderr:read_start(function(err, data)
			assert(not err, err)
			if data then
				vim.schedule(function()
					vim.notify("rg error: " .. data, vim.log.levels.WARN)
				end)
			end
		end)
	end, {
		nargs = 1,
		desc = "Search for files containing the specified pattern using ripgrep",
	})
else
	vim.notify("'rg' is not executable on this system", vim.log.levels.ERROR)
end
