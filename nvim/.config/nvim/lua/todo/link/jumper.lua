-- lua/todo/link/jumper.lua
local M = {}

local store = require("todo.store")
local utils = require("todo.link.utils")
local ui = require("todo.ui")

---------------------------------------------------------------------
-- 获取配置
---------------------------------------------------------------------
local function get_config()
	local link = require("todo.link")
	return link.get_jump_config()
end

---------------------------------------------------------------------
-- 辅助函数：查找已打开的TODO分屏窗口
---------------------------------------------------------------------
local function find_existing_todo_split_window(todo_path)
	local windows = vim.api.nvim_list_wins()

	for _, win in ipairs(windows) do
		if vim.api.nvim_win_is_valid(win) then
			local bufnr = vim.api.nvim_win_get_buf(win)
			local buf_path = vim.api.nvim_buf_get_name(bufnr)

			-- 检查是否是相同的TODO文件
			if vim.fn.fnamemodify(buf_path, ":p") == vim.fn.fnamemodify(todo_path, ":p") then
				-- 检查是否是分屏窗口（不是浮窗）
				local win_config = vim.api.nvim_win_get_config(win)
				if win_config.relative == "" then -- 不是浮窗
					return win, bufnr
				end
			end
		end
	end

	return nil, nil
end

---------------------------------------------------------------------
-- 跳转：代码 → TODO（简化逻辑）
---------------------------------------------------------------------
function M.jump_to_todo()
	local line = vim.fn.getline(".")
	local id = line:match("TODO:ref:(%w+)")

	if not id then
		print("当前行没有 TODO 链接")
		return
	end

	-- 使用 store.get_todo_link 查找
	local link = store.get_todo_link(id)

	if not link then
		print("未找到 TODO 链接记录")
		return
	end

	local todo_path = link.path
	local todo_line = link.line or 1

	-- 确保路径是绝对路径
	todo_path = vim.fn.fnamemodify(todo_path, ":p")

	-- 检查TODO文件是否存在
	if vim.fn.filereadable(todo_path) == 0 then
		print("TODO文件不存在: " .. todo_path)
		return
	end

	-- 获取配置
	local config = get_config()
	local default_mode = config.default_todo_window_mode or "float"
	local reuse_existing = config.reuse_existing_windows ~= false

	-- 1. 如果配置了复用窗口，检查是否已经有分屏窗口打开了该文件
	if reuse_existing then
		local existing_win, existing_buf = find_existing_todo_split_window(todo_path)
		if existing_win then
			-- 跳转到已存在的分屏窗口
			vim.api.nvim_set_current_win(existing_win)
			vim.api.nvim_win_set_cursor(existing_win, { todo_line, 0 })
			vim.cmd("normal! zz")
			return
		end
	end

	-- 2. 没有任何分屏窗口，使用配置的默认模式打开
	ui.open_todo_file(todo_path, default_mode, todo_line, { enter_insert = false })
end

---------------------------------------------------------------------
-- 跳转：TODO → 代码（支持配置保持分屏）
---------------------------------------------------------------------
function M.jump_to_code()
	local line = vim.fn.getline(".")
	local id = line:match("{#(%w+)}")

	if not id then
		print("当前行没有代码链接")
		return
	end

	-- 获取链接信息
	local link = store.get_code_link(id)

	if not link then
		print("未找到代码链接记录: " .. id)
		return
	end

	-- 确保路径是绝对路径
	local code_filepath = vim.fn.fnamemodify(link.path, ":p")
	local code_line = link.line

	-- 获取当前窗口信息
	local current_win = vim.api.nvim_get_current_win()

	-- 判断当前是否在 TODO 浮窗中
	local is_todo_floating = utils.is_todo_floating_window(current_win)

	-- 获取配置
	local config = get_config()
	local keep_split = config.keep_todo_split_when_jump or false

	if is_todo_floating then
		-- 如果是 TODO 浮窗，先关闭浮窗再跳转
		vim.api.nvim_win_close(current_win, false)

		-- 等待窗口关闭完成
		vim.schedule(function()
			-- 跳转到代码文件
			vim.cmd("edit " .. vim.fn.fnameescape(code_filepath))
			vim.fn.cursor(code_line, 1)
			vim.cmd("normal! zz") -- 居中显示
		end)
	else
		-- 如果是分屏TODO
		if keep_split then
			-- 配置要求保持分屏，创建新窗口显示代码
			-- 简单实现：垂直分割新窗口
			vim.cmd("vsplit")
			vim.cmd("edit " .. vim.fn.fnameescape(code_filepath))
			vim.fn.cursor(code_line, 1)
			vim.cmd("normal! zz")
		else
			-- 默认行为：在当前窗口打开代码
			vim.cmd("edit " .. vim.fn.fnameescape(code_filepath))
			vim.fn.cursor(code_line, 1)
			vim.cmd("normal! zz")
		end
	end
end

---------------------------------------------------------------------
-- 判断当前 buffer 是否是 TODO 文件
---------------------------------------------------------------------
local function is_todo_buffer(bufnr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	local name = vim.api.nvim_buf_get_name(bufnr)
	if name == "" then
		local ft = vim.api.nvim_buf_get_option(bufnr, "filetype")
		return ft == "todo"
	end
	return name:match("%.todo%.md$") or name:match("todo")
end

---------------------------------------------------------------------
-- 动态跳转函数
---------------------------------------------------------------------
function M.jump_dynamic()
	local bufnr = vim.api.nvim_get_current_buf()
	if not vim.api.nvim_buf_is_valid(bufnr) then
		print("❌ 当前 buffer 无效")
		return
	end

	if is_todo_buffer(bufnr) then
		-- 当前在 TODO 文件，跳回代码
		M.jump_to_code()
	else
		-- 当前在代码文件，跳到 TODO
		M.jump_to_todo()
	end
end

return M
