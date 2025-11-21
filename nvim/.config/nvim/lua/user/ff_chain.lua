local M = {}

local search_dirs = { vim.fn.expand("~/MCU-Project"), vim.fn.expand("~/python_project") }
local max_depth = 3
local history_file = vim.fn.expand("~/.cache/ff_history.txt")

-- 更新历史权重
local function update_history(selected)
	local updated = false
	local lines = {}
	if vim.fn.filereadable(history_file) == 1 then
		for line in io.lines(history_file) do
			local path, w = line:match("^(.-)%s+(%d+)$")
			if path == selected then
				w = tonumber(w) + 1
				updated = true
			end
			table.insert(lines, string.format("%s %d", path, w))
		end
	end
	if not updated then
		table.insert(lines, string.format("%s 1", selected))
	end
	local f = io.open(history_file, "w")
	f:write(table.concat(lines, "\n"))
	f:close()
end

-- 获取项目列表（带历史权重排序）
local function get_projects()
	local fd_cmd = { "fd", "." }
	for _, dir in ipairs(search_dirs) do
		table.insert(fd_cmd, dir)
	end
	table.insert(fd_cmd, "-t")
	table.insert(fd_cmd, "d")
	table.insert(fd_cmd, "-E")
	table.insert(fd_cmd, "*/target/*")
	table.insert(fd_cmd, "-E")
	table.insert(fd_cmd, "*/build/*")
	table.insert(fd_cmd, "-E")
	table.insert(fd_cmd, "*/.git/*")
	table.insert(fd_cmd, "-d")
	table.insert(fd_cmd, tostring(max_depth))

	local handle = io.popen(table.concat(fd_cmd, " "))
	local projects = {}
	for line in handle:lines() do
		table.insert(projects, line)
	end
	handle:close()

	-- 历史权重排序
	local weights = {}
	if vim.fn.filereadable(history_file) == 1 then
		for line in io.lines(history_file) do
			local path, w = line:match("^(.-)%s+(%d+)$")
			if path and w then
				weights[path] = tonumber(w)
			end
		end
	end

	table.sort(projects, function(a, b)
		return (weights[a] or 0) > (weights[b] or 0)
	end)
	return projects
end

-- FZF.vim 调用
local function fzf_select(items, opts)
	vim.fn["fzf#run"]({
		source = items,
		sink = opts.sink,
		options = opts.options or "",
		down = "40%",
	})
end

-- 链式选择项目 -> 文件，tab-local cwd，不带 preview
M.open_project_chain = function()
	local projects = get_projects()

	fzf_select(projects, {
		prompt = "📁 选择项目: ",
		sink = function(selected_dir)
			update_history(selected_dir)

			-- 获取文件列表
			local handle = io.popen("fd . " .. vim.fn.shellescape(selected_dir) .. " -t f")
			local files = {}
			for line in handle:lines() do
				table.insert(files, line)
			end
			handle:close()

			-- 新建 tab 并切换 tab-local cwd
			vim.cmd("tabnew")
			vim.cmd("tcd " .. selected_dir)

			-- 如果没有文件，直接打开目录
			if #files == 0 then
				vim.cmd("edit .")
				return
			end

			-- 第二层 FZF 选择文件
			fzf_select(files, {
				prompt = "📄 选择文件: ",
				sink = function(selected_file)
					vim.cmd("edit " .. vim.fn.fnamemodify(selected_file, ":t"))
				end,
			})
		end,
	})
end

return M
