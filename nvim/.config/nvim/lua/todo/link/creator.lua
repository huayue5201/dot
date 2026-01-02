-- lua/todo/link/creator.lua
local M = {}

local store = require("todo.store")
local utils = require("todo.link.utils")

-- 将辅助函数移到模块级别，这样就能在回调中访问
local function add_task_to_todo_file(todo_path, id, ui)
	-- 确保 TODO 路径是绝对路径
	todo_path = vim.fn.fnamemodify(todo_path, ":p")

	local ok, lines = pcall(vim.fn.readfile, todo_path)
	if not ok then
		print("无法读取 TODO 文件: " .. todo_path)
		return
	end

	-- 找到插入位置
	local insert_line = utils.find_task_insert_position(lines)
	local task_desc = string.format("- [ ] {#%s} 新任务", id)

	-- 插入任务行
	table.insert(lines, insert_line, task_desc)

	-- 写入文件
	local fd = io.open(todo_path, "w")
	if not fd then
		print("无法写入 TODO 文件")
		return
	end

	fd:write(table.concat(lines, "\n"))
	fd:close()

	-- 保存 TODO 位置（绝对路径）
	store.save_todo_link(id, todo_path, insert_line)

	-- ✅ 默认打开 TODO 文件
	ui.open_todo_file(todo_path, "float", insert_line, {
		enter_insert = true,
	})

	print("✅ 已创建 TODO 链接: " .. id)
end

function M.create_link()
	local ui = require("todo.ui")
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local lnum = vim.fn.line(".")

	-- 确保是绝对路径
	file_path = vim.fn.fnamemodify(file_path, ":p")

	local id = utils.generate_id()

	-- 在代码中插入标记
	local comment = utils.get_comment_prefix()
	vim.fn.append(lnum, string.format("%s TODO:ref:%s", comment, id))

	-- 保存代码位置（绝对路径）
	store.save_code_link(id, file_path, lnum + 1)

	-- 获取当前项目的TODO文件列表
	local file_manager = require("todo.ui.file_manager")
	local project = vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
	local todo_files = file_manager.get_todo_files(project)

	-- 准备选择项
	local choices = {}

	-- 添加已有的TODO文件选项
	for _, f in ipairs(todo_files) do
		local display_name = vim.fn.fnamemodify(f, ":t")
		table.insert(choices, {
			type = "existing",
			path = f,
			display = display_name,
			project = project,
		})
	end

	-- 添加新建TODO文件选项
	table.insert(choices, {
		type = "new",
		path = nil,
		display = "新建 TODO 文件",
		project = project,
	})

	-- 如果没有任何TODO文件，提示用户
	if #todo_files == 0 then
		table.insert(choices, {
			type = "info",
			path = nil,
			display = "当前项目没有TODO文件，请新建一个",
			project = project,
		})
	end

	-- 显示选择框
	vim.ui.select(choices, {
		prompt = "󰈙 选择 TODO 文件",
		format_item = function(item)
			if item.type == "existing" then
				-- 使用你想要的格式化方式
				-- 计算项目名显示宽度，最多10个字符
				local project_display = item.project
				if #project_display > 10 then
					project_display = project_display:sub(1, 7) .. "..."
				end

				-- 计算文件名显示宽度，限制长度
				local filename_display = item.display
				if #filename_display > 30 then
					filename_display = filename_display:sub(1, 27) .. "..."
				end

				-- 使用 string.format 格式化
				return string.format("󰈙 %-10s . %s", project_display, filename_display)
			elseif item.type == "new" then
				-- 新建选项的格式化
				local project_display = item.project
				if #project_display > 10 then
					project_display = project_display:sub(1, 7) .. "..."
				end

				return string.format(" %-10s . 新建 TODO 文件", project_display)
			elseif item.type == "info" then
				return string.format(" %s", item.display)
			end

			return item.display
		end,

		-- dressing.nvim / telescope.nvim 会识别这些字段
		kind = "todo-file-picker",
	}, function(choice)
		if not choice then
			-- 回滚逻辑保持不变
			vim.api.nvim_buf_set_lines(bufnr, lnum, lnum + 1, false, {})
			store.delete_code_link(id)
			return
		end

		if choice.type == "new" then
			local new_file_path = ui.create_todo_file()
			if new_file_path then
				add_task_to_todo_file(new_file_path, id, ui)
			else
				vim.api.nvim_buf_set_lines(bufnr, lnum, lnum + 1, false, {})
				store.delete_code_link(id)
			end
		elseif choice.type == "existing" then
			add_task_to_todo_file(choice.path, id, ui)
		end
	end)
end

return M
