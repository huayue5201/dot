-- lua/todo/ui/window.lua
local M = {}

local keymaps = require("todo.ui.keymaps")

---------------------------------------------------------------------
-- 内部函数：创建浮动窗口
---------------------------------------------------------------------
local function create_floating_window(bufnr, path, line_number, ui_module)
	local core = require("todo.core")
	local conceal = require("todo.ui.conceal")
	local statistics = require("todo.ui.statistics")

	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		vim.notify("无法读取文件: " .. path, vim.log.levels.ERROR)
		return
	end

	local width = math.min(math.floor(vim.o.columns * 0.6), 140)
	local height = math.min(30, math.max(10, #lines + 4))
	local col = math.floor((vim.o.columns - width) / 2)
	local row = math.floor((vim.o.lines - height) / 2)

	local win = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		col = col,
		row = row,
		border = "rounded",
		title = "📋 TODO - " .. vim.fn.fnamemodify(path, ":t"),
		style = "minimal",
	})

	conceal.apply_conceal(bufnr)

	-- 更新统计信息的函数
	local function update_summary()
		if not vim.api.nvim_win_is_valid(win) then
			return
		end

		local current_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
		local stat = core.summarize(current_lines)
		local footer_text = statistics.format_summary(stat)

		pcall(vim.api.nvim_win_set_config, win, {
			footer = { { " " .. footer_text .. " ", "Number" } },
			footer_pos = "right",
		})
	end

	-- 设置键位映射
	keymaps.setup_keymaps(bufnr, win, ui_module)

	return win, update_summary
end

---------------------------------------------------------------------
-- 浮动窗口模式
---------------------------------------------------------------------
function M.show_floating(path, line_number, enter_insert, ui_module)
	local bufnr = vim.fn.bufadd(path)
	vim.fn.bufload(bufnr)

	-- 设置缓冲区选项
	local buf_opts = {
		buftype = "",
		bufhidden = "wipe",
		modifiable = true,
		readonly = false,
		swapfile = false,
		filetype = "markdown",
	}

	for opt, val in pairs(buf_opts) do
		vim.bo[bufnr][opt] = val
	end

	local win, update_summary = create_floating_window(bufnr, path, line_number, ui_module)
	if not win then
		return
	end

	vim.defer_fn(function()
		if ui_module and ui_module.refresh then
			ui_module.refresh(bufnr)
		end
		update_summary()

		if line_number then
			vim.api.nvim_win_set_cursor(win, { line_number, 0 })
			vim.api.nvim_win_call(win, function()
				vim.cmd("normal! zz")
			end)
			-- 进入行尾插入模式
			if enter_insert then
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
			end
		end
	end, 50)

	local augroup = vim.api.nvim_create_augroup("TodoFloating_" .. path:gsub("[^%w]", "_"), { clear = true })

	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(win),
		once = true,
		callback = function()
			vim.api.nvim_del_augroup_by_id(augroup)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = augroup,
		buffer = bufnr,
		callback = function()
			if vim.api.nvim_win_is_valid(win) then
				if ui_module and ui_module.refresh then
					ui_module.refresh(bufnr)
				end
				update_summary()
			end
		end,
	})

	return bufnr, win
end

---------------------------------------------------------------------
-- 分割窗口模式
---------------------------------------------------------------------
function M.show_split(path, line_number, enter_insert, split_direction, ui_module)
	-- 保存当前窗口
	local current_win = vim.api.nvim_get_current_win()

	-- 根据分割方向创建新窗口
	if split_direction == "vertical" or split_direction == "v" then
		vim.cmd("vsplit")
	else
		vim.cmd("split")
	end

	-- 获取新窗口
	local new_win = vim.api.nvim_get_current_win()

	-- 在新窗口中打开文件
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	local bufnr = vim.api.nvim_get_current_buf()

	-- 设置合适的窗口大小
	if split_direction == "vertical" or split_direction == "v" then
		-- 垂直分割，设置宽度为80或屏幕宽度的50%
		local width = math.min(80, math.floor(vim.o.columns * 0.5))
		vim.api.nvim_win_set_width(new_win, width)
	else
		-- 水平分割，设置高度为20或屏幕高度的50%
		local height = math.min(20, math.floor(vim.o.lines * 0.5))
		vim.api.nvim_win_set_height(new_win, height)
	end

	-- 设置缓冲区选项
	local buf_opts = {
		buftype = "",
		modifiable = true,
		readonly = false,
		swapfile = false,
		filetype = "markdown",
	}

	for opt, val in pairs(buf_opts) do
		vim.bo[bufnr][opt] = val
	end

	-- 应用conceal设置
	local conceal = require("todo.ui.conceal")
	conceal.apply_conceal(bufnr)

	-- 刷新渲染
	if ui_module and ui_module.refresh then
		ui_module.refresh(bufnr)
	end

	-- 跳转到指定行
	if line_number then
		vim.api.nvim_win_set_cursor(new_win, { line_number, 0 })
		vim.api.nvim_win_call(new_win, function()
			vim.cmd("normal! zz")
		end)
	end

	-- 设置窗口本地键位
	keymaps.setup_keymaps(bufnr, new_win, ui_module)

	-- 创建自动命令组来管理事件
	local augroup = vim.api.nvim_create_augroup("TodoSplit_" .. path:gsub("[^%w]", "_"), { clear = true })

	vim.api.nvim_create_autocmd("WinClosed", {
		group = augroup,
		pattern = tostring(new_win),
		once = true,
		callback = function()
			vim.api.nvim_del_augroup_by_id(augroup)
		end,
	})

	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI", "BufWritePost" }, {
		group = augroup,
		buffer = bufnr,
		callback = function()
			if vim.api.nvim_win_is_valid(new_win) then
				if ui_module and ui_module.refresh then
					ui_module.refresh(bufnr)
				end
			end
		end,
	})

	-- 进入行尾插入模式
	if enter_insert then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
	end

	return bufnr, new_win
end

---------------------------------------------------------------------
-- 编辑模式（直接编辑）
---------------------------------------------------------------------
function M.show_edit(path, line_number, enter_insert, ui_module)
	vim.cmd("edit " .. vim.fn.fnameescape(path))
	local bufnr = vim.api.nvim_get_current_buf()

	-- 设置缓冲区选项
	local buf_opts = {
		buftype = "",
		modifiable = true,
		readonly = false,
		swapfile = false,
		filetype = "markdown",
	}

	for opt, val in pairs(buf_opts) do
		vim.bo[bufnr][opt] = val
	end

	-- 应用conceal设置
	local conceal = require("todo.ui.conceal")
	conceal.apply_conceal(bufnr)

	-- 刷新渲染
	if ui_module and ui_module.refresh then
		ui_module.refresh(bufnr)
	end

	-- 跳转到指定行
	if line_number then
		vim.fn.cursor(line_number, 1)
		vim.cmd("normal! zz")
	end

	-- 进入行尾插入模式
	if enter_insert then
		vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("A", true, false, true), "n", true)
	end

	return bufnr
end

return M
