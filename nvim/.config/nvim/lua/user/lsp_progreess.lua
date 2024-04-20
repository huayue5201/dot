-- user.lsp_progress.lua

-- 图标定义：旋转图标和完成状态图标
local icons = {
	spinner = { "⣾", "⣽", "⣻", "⢿", "⡿", "⣟", "⣯", "⣷" },
	done = " ",
}

-- 为接收进度通知的每个客户端维护属性
local clients = {}
local total_wins = 0 -- 总窗口数

-- 抑制在渲染窗口期间可能出现的错误
local function guard(callable)
	local whitelist = {
		"E11: Invalid in command%-line window",
		"E523: Not allowed here",
		"E565: Not allowed to change",
	}
	local ok, err = pcall(callable)
	if ok then
		return true
	end
	if type(err) ~= "string" then
		error(err)
	end
	for _, msg in ipairs(whitelist) do
		if string.find(err, msg) then
			return false
		end
	end
	error(err)
end

-- 初始化或重置给定客户端的属性
local function init_or_reset(client)
	client.is_done = false -- 是否完成
	client.spinner_idx = 0 -- 旋转图标索引
	client.winid = nil -- 窗口ID
	client.bufnr = nil -- 缓冲区编号
	client.message = nil -- 信息
	client.pos = total_wins + 1 -- 窗口位置
	client.timer = nil -- 定时器
end

-- 获取当前浮动窗口的行位置
local function get_win_row(pos)
	return vim.o.lines - vim.o.cmdheight - 1 - pos * 3
end

-- 更新窗口配置
local function win_update_config(client)
	vim.api.nvim_win_set_config(client.winid, {
		relative = "editor",
		width = #client.message,
		height = 1,
		row = get_win_row(client.pos),
		col = vim.o.columns - #client.message,
	})
end

-- 关闭窗口并删除相关缓冲区
local function close_window(winid, bufnr)
	if vim.api.nvim_win_is_valid(winid) then
		vim.api.nvim_win_close(winid, true)
	end
	if vim.api.nvim_buf_is_valid(bufnr) then
		vim.api.nvim_buf_delete(bufnr, { force = true })
	end
end

-- 组装输出进度消息
local function process_message(client, name, params)
	local message = "[" .. name .. "]"
	local kind = params.value.kind
	local title = params.value.title
	if title then
		message = message .. " " .. title .. ":"
	end
	if kind == "end" then
		client.is_done = true
		message = icons.done .. " " .. message .. " 完成!"
	else
		client.is_done = false
		local raw_msg = params.value.message
		local pct = params.value.percentage
		if raw_msg then
			message = message .. " " .. raw_msg
		end
		if pct then
			message = string.format("%s (%3d%%)", message, pct)
		end
		-- 旋转图标
		local idx = client.spinner_idx
		idx = idx == #icons.spinner * 4 and 1 or idx + 1
		message = icons.spinner[math.ceil(idx / 4)] .. " " .. message
		client.spinner_idx = idx
	end
	return message
end

-- 在浮动窗口中显示进度消息
local function show_message(client)
	local winid = client.winid
	if
		winid == nil
		or not vim.api.nvim_win_is_valid(winid)
		or vim.api.nvim_win_get_tabpage(winid) ~= vim.api.nvim_get_current_tabpage()
	then
		local success = guard(function()
			winid = vim.api.nvim_open_win(client.bufnr, false, {
				relative = "editor",
				width = #client.message,
				height = 1,
				row = get_win_row(client.pos),
				col = vim.o.columns - #client.message,
				focusable = false,
				style = "minimal",
				noautocmd = true,
				border = vim.g.border_style,
			})
		end)
		if not success then
			return
		end
		client.winid = winid
		total_wins = total_wins + 1
	else
		win_update_config(client)
	end
	vim.wo[winid].winhl = "Normal:Normal"
	guard(function()
		vim.api.nvim_buf_set_lines(client.bufnr, 0, 1, false, { client.message })
	end)
end

-- 进度通知处理程序(逻辑代码)
local function handler(args)
	-- 获取客户端ID
	local client_id = args.data.client_id
	-- 如果该客户端尚未初始化，则进行初始化
	if clients[client_id] == nil then
		clients[client_id] = {}
		init_or_reset(clients[client_id])
	end
	-- 获取当前客户端的属性
	local cur_client = clients[client_id]
	-- 如果缓冲区编号尚未初始化，则创建一个新的缓冲区
	if cur_client.bufnr == nil then
		cur_client.bufnr = vim.api.nvim_create_buf(false, true)
	end
	-- 如果定时器尚未初始化，则创建一个新的定时器
	if cur_client.timer == nil then
		cur_client.timer = vim.uv.new_timer()
	end
	-- 处理进度消息并更新消息内容
	cur_client.message = process_message(cur_client, vim.lsp.get_client_by_id(client_id).name, args.data.result)
	-- 在浮动窗口中显示进度消息
	show_message(cur_client)
	-- 如果任务已完成，则执行后续操作
	if cur_client.is_done then
		cur_client.timer:start(
			2000,
			100,
			vim.schedule_wrap(function()
				-- 如果任务未完成且窗口ID存在，则停止定时器
				if not cur_client.is_done and cur_client.winid ~= nil then
					cur_client.timer:stop()
					return
				end
				local success = false
				-- 如果窗口ID和缓冲区编号都存在，则关闭窗口并删除缓冲区
				if cur_client.winid ~= nil and cur_client.bufnr ~= nil then
					success = guard(function()
						close_window(cur_client.winid, cur_client.bufnr)
					end)
				end
				-- 如果操作成功，则停止定时器并进行其他清理工作
				if success then
					cur_client.timer:stop()
					cur_client.timer:close()
					total_wins = total_wins - 1
					-- 更新其他客户端的窗口位置
					for _, c in pairs(clients) do
						if c.is_done and c.pos > cur_client.pos then
							c.pos = c.pos - 1
							win_update_config(c)
						end
					end
					-- 重置当前客户端的属性
					init_or_reset(cur_client)
				end
			end)
		)
	end
end

local M = {}
-- 设置LSP进度
function M.setup_lsp_progress()
	local group = vim.api.nvim_create_augroup("lsp_progress", { clear = true })
	vim.api.nvim_create_autocmd({ "LspProgress" }, {
		group = group,
		pattern = "*",
		callback = function(args)
			handler(args)
		end,
	})
end

return M
