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
-- ===========================
-- 关闭缓冲
-- ===========================
vim.api.nvim_create_user_command("DeleteBuffer", function()
	-- 引入 utils 模块，获取 close_commands 配置
	local close_commands = require("config.utils").close_commands
	-- 获取所有列出的缓冲区
	local buflisted = vim.fn.getbufinfo({ buflisted = 1 })
	-- 获取当前窗口和缓冲区的编号
	local cur_winnr, cur_bufnr = vim.fn.winnr(), vim.fn.bufnr()
	-- 获取当前窗口的布局信息
	local layout = vim.fn.winlayout()
	-- 获取当前缓冲区的类型（优先 filetype，否则 buftype）
	local current_type = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
	-- 获取关闭命令，如果没有命令则使用默认的 "bd"
	local command = close_commands[current_type]
	if not command then
		command = "bd"
	end

	-- 如果找到匹配的关闭命令，执行该命令并返回
	if command then
		command = command:gsub("<cr>", "")
		vim.cmd(command)
		return
	end

	-- 处理分屏窗口
	if layout[1] ~= "leaf" then
		vim.cmd("bd")
		return
	end

	-- 获取当前缓冲区的索引位置
	local current_index = 0
	for i, buf in ipairs(buflisted) do
		if buf.bufnr == cur_bufnr then
			current_index = i
			break
		end
	end

	-- 如果当前窗口是唯一窗口，不执行关闭操作
	local windows = vim.api.nvim_list_wins()
	if #windows == 1 then
		print("无法关闭最后一个窗口！")
		return
	end

	-- 切换到前一个或下一个缓冲区
	if current_index > 1 then
		vim.cmd("bp")
	elseif current_index < #buflisted then
		vim.cmd("bn")
	else
		vim.cmd("bp")
	end

	-- 切换回原始窗口
	vim.cmd(string.format("%d wincmd w", cur_winnr))

	-- 判断当前缓冲区是否是一个终端缓冲区
	local is_terminal = vim.fn.getbufvar(cur_bufnr, "&buftype") == "terminal"
	-- 如果是终端缓冲区，强制删除；否则，使用 confirm 进行确认删除
	vim.cmd(is_terminal and "bd! #" or "silent! confirm bd #")
end, {
	desc = "删除当前缓冲区，并进行未保存更改和窗口管理的额外检查",
	nargs = 0, -- 不需要参数
})

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
