local fzf = require("fzf-lua")
local M = {}

local search_dirs = {
	vim.fn.expand("~/MCU-Project"),
	vim.fn.expand("~/python_project"),
	vim.fn.expand("~/golang_project"),
}
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

-- 获取项目列表
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

	-- 权重
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

--========================--
--      fzf-lua 版本       --
--========================--

M.open_project_chain = function()
	local projects = get_projects()

	fzf.fzf_exec(projects, {
		prompt = "📁 选择项目 > ",
		actions = {
			["default"] = function(selected)
				local selected_dir = selected[1]
				update_history(selected_dir)

				-- 获取文件列表
				local handle = io.popen("fd . " .. vim.fn.shellescape(selected_dir) .. " -t f")
				local files = {}
				for line in handle:lines() do
					table.insert(files, line)
				end
				handle:close()

				-- 新 tab + tab-local cwd
				vim.cmd("tabnew")
				vim.cmd("tcd " .. selected_dir)

				if #files == 0 then
					vim.cmd("edit .")
					return
				end

				-- 第二层 FZF
				fzf.fzf_exec(files, {
					prompt = "📄 选择文件 > ",
					actions = {
						["default"] = function(sel)
							local path = sel[1]
							vim.cmd("edit " .. vim.fn.fnamemodify(path, ":t"))
						end,
					},
				})
			end,
		},
	})
end

return M
