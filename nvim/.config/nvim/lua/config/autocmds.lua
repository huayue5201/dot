-- 使用 autocmd 对大文件禁用折叠
vim.api.nvim_create_autocmd("BufRead", {
	callback = function(args)
		local line_count = vim.api.nvim_buf_line_count(args.buf)
		if line_count > 10000 then -- 超过10000行就禁用折叠
			vim.opt_local.foldmethod = "manual"
			vim.opt_local.foldenable = false
		end
	end,
})

-- 保存时自动删除尾随空格
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = { "*.txt", "*.lua", "*.js", "*.py" },
	desc = "保存前自动删除行尾空格",
	command = "%s/\\s\\+$//e",
})

-- 恢复上次光标位置
vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "打开文件时恢复上次光标位置",
	group = vim.api.nvim_create_augroup("LastPlace", { clear = true }),
	pattern = "*",
	callback = function()
		local mark = vim.api.nvim_buf_get_mark(0, '"')
		local lines = vim.api.nvim_buf_get_lines(0, 0, -1, false)
		if #lines > 0 and mark[1] > 0 and mark[1] <= #lines then
			vim.schedule(function()
				pcall(vim.api.nvim_win_set_cursor, 0, mark)
			end)
		end
	end,
})

-- =============================================
-- 快捷键映射配置
-- =============================================

-- 文件类型特定的快捷键映射
vim.api.nvim_create_autocmd({ "FileType", "BufEnter" }, {
	desc = "根据文件类型设置按键",
	group = vim.api.nvim_create_augroup("CustomKeyMappings", { clear = true }),
	callback = function()
		local buf_keymaps = require("utils.utils").buf_keymaps
		local ft = vim.bo.filetype ~= "" and vim.bo.filetype or vim.bo.buftype
		local set_markers = vim.b.keymaps_set or {}

		for key, configs in pairs(buf_keymaps) do
			local conf = configs[ft]
			if conf and not set_markers[key] then
				local opts = { buffer = true, silent = true, noremap = true, nowait = true }
				if type(conf.cmd) == "function" then
					vim.keymap.set("n", key, conf.cmd, opts)
				else
					vim.keymap.set("n", key, function()
						vim.cmd(conf.cmd)
					end, opts)
				end
				set_markers[key] = true
			end
		end

		vim.b.keymaps_set = set_markers
	end,
})

-- =============================================
-- Quickfix 和 Location List 增强
-- =============================================

-- 删除 quickfix 或 location list 项目的函数
local function delete_qf_items()
	local win_id = vim.api.nvim_get_current_win()
	local win_info = vim.fn.getwininfo(win_id)[1]
	local is_loc = win_info and win_info.loclist == 1
	local is_qf = win_info and win_info.quickfix == 1 and not is_loc

	if not (is_qf or is_loc) then
		return
	end

	local list = is_qf and vim.fn.getqflist() or vim.fn.getloclist(0)
	if not list or #list == 0 then
		return
	end

	-- 获取当前模式
	local mode = vim.api.nvim_get_mode().mode
	local start_idx, end_idx

	if mode == "n" then
		-- 普通模式：删除当前行（或 count 指定的多行）
		start_idx = vim.fn.line(".")
		end_idx = start_idx + (vim.v.count > 0 and vim.v.count - 1 or 0)
	else
		-- 可视模式：删除选中行
		start_idx = vim.fn.line("v")
		end_idx = vim.fn.line(".")
		vim.cmd("normal! <esc>") -- 退出可视模式
	end

	-- 确保索引有效
	start_idx = math.max(1, math.min(start_idx, #list))
	end_idx = math.max(1, math.min(end_idx, #list))
	if start_idx > end_idx then
		start_idx, end_idx = end_idx, start_idx
	end

	-- 创建新的列表（排除要删除的项目）
	local new_list = {}
	for i = 1, #list do
		if i < start_idx or i > end_idx then
			table.insert(new_list, list[i])
		end
	end

	-- 更新列表
	if is_qf then
		vim.fn.setqflist(new_list, "r")
	else
		vim.fn.setloclist(0, new_list, "r")
	end

	-- 调整光标位置
	local new_pos = math.min(start_idx, #new_list)
	if new_pos > 0 then
		vim.fn.cursor(new_pos, 1)
	end
end

-- 检查指定类型窗口是否已打开
local function is_window_open(win_type)
	for _, win in ipairs(vim.fn.getwininfo()) do
		if win_type == "quickfix" and win.quickfix == 1 then
			return true
		elseif win_type == "loclist" and win.loclist == 1 then
			return true
		end
	end
	return false
end

-- Quickfix 和 Location List 窗口的增强设置
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("QuickfixTweaks", { clear = true }),
	pattern = "qf",
	desc = "Quickfix 和 Location List 窗口的快捷键和设置",
	callback = function()
		local win_id = vim.api.nvim_get_current_win()
		local win_info = vim.fn.getwininfo(win_id)[1]

		local is_loc = win_info and win_info.loclist == 1
		local is_qf = win_info and win_info.quickfix == 1 and not is_loc

		-- 禁用 buffer 列表，防止显示在 buffer list 中
		vim.api.nvim_set_option_value("buflisted", false, { buf = 0 })

		-- 根据不同类型设置关闭命令
		local close_cmd = is_qf and "<CMD>cclose<CR>" or "<CMD>lclose<CR>"

		-- 设置快捷键
		vim.keymap.set("n", "<ESC>", close_cmd, { buffer = true, silent = true })
		vim.keymap.set("n", "dd", delete_qf_items, { buffer = true, desc = "Delete current item" })
		vim.keymap.set("x", "d", delete_qf_items, { buffer = true, desc = "Delete selected items" })
		vim.keymap.set("n", "q", close_cmd, { buffer = true, silent = true })

		-- 快捷键切换到下一个/上一个条目
		if is_qf then
			vim.keymap.set("n", "L", "<CMD>cnext<CR>", { buffer = true, desc = "Next quickfix item" })
			vim.keymap.set("n", "H", "<CMD>cprev<CR>", { buffer = true, desc = "Previous quickfix item" })
		elseif is_loc then
			vim.keymap.set("n", "L", "<CMD>lnext<CR>", { buffer = true, desc = "Next location item" })
			vim.keymap.set("n", "H", "<CMD>lprev<CR>", { buffer = true, desc = "Previous location item" })
		end

		-- 更新状态栏显示
		local list_type = is_qf and "Quickfix" or "Location List"
		vim.opt_local.statusline = list_type .. " %<%f %=%-14.(%l/%L%)%P"
	end,
})

-- 创建切换 Quickfix/Location List 的用户命令
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
end, { desc = "切换 Quickfix 或 Location List 窗口", nargs = "?" })
