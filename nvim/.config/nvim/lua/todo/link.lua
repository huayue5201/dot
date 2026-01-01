-- lua/todo/link.lua
local store = require("todo.store")
local M = {}

---------------------------------------------------------------------
-- 生成唯一 ID
---------------------------------------------------------------------
local function generate_id()
	return string.format("%06x", math.random(0, 0xFFFFFF))
end

---------------------------------------------------------------------
-- 在 TODO 文件中查找任务插入位置
---------------------------------------------------------------------
local function find_task_insert_position(lines)
	for i, line in ipairs(lines) do
		if line:match("^%s*[-*]%s+%[[ xX]%]") then
			return i
		end
	end

	for i, line in ipairs(lines) do
		if line:match("^#+ ") then
			for j = i + 1, #lines do
				if lines[j] == "" then
					return j + 1
				end
			end
			return i + 1
		end
	end

	return 1
end

---------------------------------------------------------------------
-- 查找已存在的 TODO 分屏窗口
---------------------------------------------------------------------
local function find_existing_todo_split()
	for _, win in ipairs(vim.api.nvim_list_wins()) do
		local config = vim.api.nvim_win_get_config(win)
		-- 检查是否为普通窗口（非浮窗）
		if config.relative == "" then
			local bufnr = vim.api.nvim_win_get_buf(win)
			local bufname = vim.api.nvim_buf_get_name(bufnr)
			-- 检查是否是 TODO 文件
			if bufname:match("%.todo%.md$") then
				return win
			end
		end
	end
	return nil
end

---------------------------------------------------------------------
-- 创建代码 → TODO 链接
---------------------------------------------------------------------
local function get_comment_prefix()
	local cs = vim.bo.commentstring or "%s"
	cs = cs:gsub("^%s+", ""):gsub("%s+$", "")

	local block_prefix = cs:match("^(.*)%%s")
	if block_prefix then
		block_prefix = block_prefix:gsub("%s+$", "")
		return block_prefix
	end

	return "//"
end

function M.create_link()
	local bufnr = vim.api.nvim_get_current_buf()
	local file_path = vim.api.nvim_buf_get_name(bufnr)
	local lnum = vim.fn.line(".")

	-- 确保是绝对路径
	file_path = vim.fn.fnamemodify(file_path, ":p")

	local id = generate_id()

	-- 在代码中插入标记
	local comment = get_comment_prefix()
	vim.fn.append(lnum, string.format("%s TODO:ref:%s", comment, id))

	-- 保存代码位置（绝对路径）
	store.save_code_link(id, file_path, lnum + 1)

	-- 选择 TODO 文件
	require("todo.ui").select_todo_file("current", function(item)
		if not item then
			return
		end

		local todo_path = item.path
		-- 确保 TODO 路径是绝对路径
		todo_path = vim.fn.fnamemodify(todo_path, ":p")

		local ok, lines = pcall(vim.fn.readfile, todo_path)
		if not ok then
			print("无法读取 TODO 文件: " .. todo_path)
			return
		end

		-- 找到插入位置
		local insert_line = find_task_insert_position(lines)
		local task_desc = string.format("- [ ] {#%s} 新任务", id)

		-- 插入任务行
		table.insert(lines, insert_line, task_desc)

		-- 写入文件
		local fd = io.open(todo_path, "w")
		if fd then
			fd:write(table.concat(lines, "\n"))
			fd:close()
		else
			print("无法写入 TODO 文件")
			return
		end

		-- 保存 TODO 位置（绝对路径）
		store.save_todo_link(id, todo_path, insert_line)

		-- 打开 TODO 文件（默认浮窗，并进入插入模式）
		require("todo.ui").open_todo_file(todo_path, "floating", insert_line, { enter_insert = true })

		print("✅ 已创建 TODO 链接: " .. id)
	end)
end

---------------------------------------------------------------------
-- 跳转：代码 → TODO
---------------------------------------------------------------------
function M.jump_to_todo()
	local line = vim.fn.getline(".")
	local id = line:match("TODO:ref:(%w+)")

	if not id then
		print("当前行没有 TODO 链接")
		return
	end

	-- 获取链接信息（新版 json_store 已将所有 todo_links 设为全局）
	local link = store.get_todo_link(id)

	-- 新版不需要跨项目查找，因为 todo_links 已经是全局命名空间
	if not link then
		print("未找到 TODO 链接记录")
		return
	end

	-- 检查是否有已存在的 TODO 分屏
	local existing_todo_split = find_existing_todo_split()

	if existing_todo_split then
		-- 在已存在的 TODO 分屏中打开
		vim.api.nvim_set_current_win(existing_todo_split)
		require("todo.ui").open_todo_file(link.path, "current", link.line, { enter_insert = false })
	else
		-- 默认浮窗打开
		require("todo.ui").open_todo_file(link.path, "floating", link.line, { enter_insert = false })
	end
end

---------------------------------------------------------------------
-- 跳转：TODO → 代码
---------------------------------------------------------------------
function M.jump_to_code()
	local line = vim.fn.getline(".")
	local id = line:match("{#(%w+)}")

	if not id then
		print("当前行没有代码链接")
		return
	end

	-- 获取链接信息（新版 json_store 已将所有 code_links 设为全局）
	local link = store.get_code_link(id)

	if not link then
		print("未找到代码链接记录: " .. id)
		return
	end

	-- 确保路径是绝对路径
	local filepath = vim.fn.fnamemodify(link.path, ":p")

	-- 获取当前窗口信息
	local current_win = vim.api.nvim_get_current_win()
	local win_config = vim.api.nvim_win_get_config(current_win)
	local is_float = win_config.relative ~= ""

	-- 判断当前是否在 TODO 浮窗中
	local is_todo_floating = false
	if is_float then
		local bufname = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(current_win))
		if bufname:match("%.todo%.md$") or bufname:match("todo") then
			is_todo_floating = true
		end
	end

	-- 使用同步方式跳转，确保跳转完成
	if is_todo_floating then
		-- 如果是 TODO 浮窗，先关闭浮窗再跳转
		vim.api.nvim_win_close(current_win, false)

		-- 等待窗口关闭完成
		vim.schedule(function()
			-- 跳转到代码文件
			vim.cmd("edit " .. vim.fn.fnameescape(filepath))
			vim.fn.cursor(link.line, 1)
			vim.cmd("normal! zz") -- 居中显示
		end)
	else
		-- 如果是普通窗口，直接跳转
		vim.cmd("edit " .. vim.fn.fnameescape(filepath))
		vim.fn.cursor(link.line, 1)
		vim.cmd("normal! zz") -- 居中显示
	end
end

---------------------------------------------------------------------
-- 自动同步：代码文件状态渲染
---------------------------------------------------------------------
local ns = vim.api.nvim_create_namespace("todo_status")

-- 简单的 todo 文件缓存（当前 Neovim 会话内）
local todo_file_cache = {}

local function read_todo_file(path)
	local stat = vim.uv and vim.uv.fs_stat(path) or vim.loop and vim.loop.fs_stat(path)
	local mtime = stat and stat.mtime and (stat.mtime.sec or stat.mtime) or nil

	local cache = todo_file_cache[path]
	if cache and cache.mtime == mtime and cache.lines then
		return cache.lines
	end

	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil
	end

	todo_file_cache[path] = {
		lines = lines,
		mtime = mtime,
	}

	return lines
end

function M.render_code_status(bufnr)
	if not bufnr or not vim.api.nvim_buf_is_valid(bufnr) then
		return
	end

	vim.api.nvim_buf_clear_namespace(bufnr, ns, 0, -1)

	local current_file = vim.api.nvim_buf_get_name(bufnr)
	if not current_file or current_file == "" then
		return
	end

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
	if not lines then
		return
	end

	-- 预扫描：收集所有 id → { line_idx }
	local id_to_lines = {}
	for i, line in ipairs(lines) do
		local id = line:match("TODO:ref:(%w+)")
		if id then
			id_to_lines[id] = id_to_lines[id] or {}
			table.insert(id_to_lines[id], i)
		end
	end

	if vim.tbl_isempty(id_to_lines) then
		return
	end

	-- 一次性获取所有 todo 链接
	local store = require("todo.store")

	-- 为每个 id 找到对应 todo 行状态
	local todo_line_cache = {}

	for id, code_lines in pairs(id_to_lines) do
		local todo = store.get_todo_link(id)
		if todo and todo.path and todo.line then
			local todo_lines = todo_line_cache[todo.path]
			if not todo_lines then
				todo_lines = read_todo_file(todo.path)
				todo_line_cache[todo.path] = todo_lines
			end

			if todo_lines then
				local todo_line = todo_lines[todo.line]
				local status = todo_line and todo_line:match("%[(.)%]")

				local icon = (status == "x" or status == "X") and "✓" or "☐"
				local text = (status == "x" or status == "X") and "已完成" or "未完成"
				local hl_group = (status == "x" or status == "X") and "String" or "Error"

				for _, code_lnum in ipairs(code_lines) do
					if vim.api.nvim_buf_is_valid(bufnr) then
						vim.api.nvim_buf_set_extmark(bufnr, ns, code_lnum - 1, -1, {
							virt_text = {
								{ "  " .. icon .. " " .. text, hl_group },
							},
							virt_text_pos = "eol",
							hl_mode = "combine",
						})
					end
				end
			end
		end
	end
end

function M.sync_code_links()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local found = {}
	for i, line in ipairs(lines) do
		local id = line:match("TODO:ref:(%w+)")
		if id then
			found[id] = i
		end
	end

	-- 新版 json_store 已将所有 code_links 设为全局，不再需要跨项目查找
	-- 直接使用 store 模块提供的函数
	local all_code_links = store.get_all_code_links()

	for id, info in pairs(all_code_links) do
		if info.path == path then
			if not found[id] then
				store.delete_code_link(id)
			elseif found[id] ~= info.line then
				store.save_code_link(id, path, found[id])
			end
		end
	end

	vim.schedule(function()
		M.render_code_status(bufnr)
	end)
end

function M.sync_todo_links()
	local bufnr = vim.api.nvim_get_current_buf()
	local path = vim.api.nvim_buf_get_name(bufnr)
	-- 确保是绝对路径
	path = vim.fn.fnamemodify(path, ":p")

	local lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)

	local found = {}
	for i, line in ipairs(lines) do
		local id = line:match("{#(%w+)}")
		if id then
			found[id] = i
		end
	end

	-- 同步当前文件的链接
	local all = store.get_all_todo_links()
	for id, info in pairs(all) do
		-- 比较绝对路径
		if vim.fn.fnamemodify(info.path, ":p") == path then
			if not found[id] then
				store.delete_todo_link(id)
			elseif found[id] ~= info.line then
				store.save_todo_link(id, path, found[id])
			end
		end
	end

	-- 更新相关代码文件的显示
	for id, _ in pairs(found) do
		local code = store.get_code_link(id)
		if code then
			local cbuf = vim.fn.bufnr(code.path)
			if cbuf ~= -1 then
				vim.schedule(function()
					M.render_code_status(cbuf)
				end)
			end
		end
	end
end

---------------------------------------------------------------------
-- 悬浮预览
---------------------------------------------------------------------
function M.preview_todo()
	local line = vim.fn.getline(".")
	local id = line:match("TODO:ref:(%w+)")

	if not id then
		return
	end

	local link = store.get_todo_link(id)
	if not link then
		return
	end

	local ok, lines = pcall(vim.fn.readfile, link.path)
	if not ok then
		return
	end

	local start_line = math.max(1, link.line - 3)
	local end_line = math.min(#lines, link.line + 3)
	local context_lines = {}

	for i = start_line, end_line do
		table.insert(context_lines, lines[i])
	end

	local content = table.concat(context_lines, "\n")

	vim.lsp.util.open_floating_preview({ content }, "markdown", {
		border = "rounded",
		focusable = true,
	})
end

function M.preview_code()
	local line = vim.fn.getline(".")
	local id = line:match("{#(%w+)}")

	if not id then
		return
	end

	local link = store.get_code_link(id)
	if not link then
		return
	end

	local ok, lines = pcall(vim.fn.readfile, link.path)
	if not ok then
		return
	end

	local start_line = math.max(1, link.line - 3)
	local end_line = math.min(#lines, link.line + 3)
	local context_lines = {}

	for i = start_line, end_line do
		table.insert(context_lines, lines[i])
	end

	local content = table.concat(context_lines, "\n")

	vim.lsp.util.open_floating_preview({ content }, "markdown", {
		border = "rounded",
		focusable = true,
	})
end

---------------------------------------------------------------------
-- 清理无效链接
---------------------------------------------------------------------
function M.cleanup_all_links()
	local todo_cleaned = 0
	local code_cleaned = 0

	-- 清理 todo_links 命名空间（新版使用全局存储）
	local all_todo = store.get_all_todo_links()
	if all_todo then
		for id, info in pairs(all_todo) do
			-- 检查TODO文件是否存在
			local file_ok, todo_lines = pcall(vim.fn.readfile, info.path)
			if not file_ok then
				store.delete_todo_link(id)
				todo_cleaned = todo_cleaned + 1
			else
				-- 检查ID是否还在文件中
				local found = false
				for _, line in ipairs(todo_lines) do
					if line:match("{#" .. id .. "}") then
						found = true
						break
					end
				end
				if not found then
					store.delete_todo_link(id)
					todo_cleaned = todo_cleaned + 1
				end
			end
		end
	end

	-- 清理 code_links 命名空间（新版使用全局存储）
	local all_code = store.get_all_code_links()
	if all_code then
		for id, info in pairs(all_code) do
			-- 检查代码文件是否存在
			local file_ok, code_lines = pcall(vim.fn.readfile, info.path)
			if not file_ok then
				store.delete_code_link(id)
				code_cleaned = code_cleaned + 1
			else
				-- 检查TODO标记是否还在文件中
				local found = false
				for _, line in ipairs(code_lines) do
					if line:match("TODO:ref:" .. id) then
						found = true
						break
					end
				end
				if not found then
					store.delete_code_link(id)
					code_cleaned = code_cleaned + 1
				end
			end
		end
	end

	print(
		string.format("✅ 清理完成，清理了 %d 个TODO链接和 %d 个代码链接", todo_cleaned, code_cleaned)
	)
end

---------------------------------------------------------------------
-- 搜索功能
---------------------------------------------------------------------
function M.search_links_by_file(filepath)
	-- 新版使用全局存储，不需要跨项目搜索
	local todo_results = store.find_todo_links_by_file(filepath)
	local code_results = store.find_code_links_by_file(filepath)

	return {
		todo_links = todo_results,
		code_links = code_results,
	}
end

function M.search_links_by_pattern(pattern)
	-- 新版使用全局存储
	local todo_all = store.get_all_todo_links()
	local code_all = store.get_all_code_links()
	local results = {}

	-- 搜索TODO链接
	for id, link in pairs(todo_all) do
		-- 读取文件内容
		local ok, lines = pcall(vim.fn.readfile, link.path)
		if ok then
			local line_content = lines[link.line] or ""
			if line_content:match(pattern) then
				results[id] = {
					type = "todo",
					link = link,
					content = line_content,
				}
			end
		end
	end

	-- 搜索代码链接
	for id, link in pairs(code_all) do
		local ok, lines = pcall(vim.fn.readfile, link.path)
		if ok then
			local line_content = lines[link.line] or ""
			if line_content:match(pattern) then
				results[id] = {
					type = "code",
					link = link,
					content = line_content,
				}
			end
		end
	end

	return results
end

return M
