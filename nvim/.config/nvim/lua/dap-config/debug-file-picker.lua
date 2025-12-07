-- ~/.config/nvim/lua/dap-config/debug-file-picker.lua
local M = {}

-- 查找项目根目录（保持不变）
local function find_project_root()
	local cwd = vim.fn.getcwd()
	local markers = {
		".git",
		"Cargo.toml",
		"package.json",
		"go.mod",
		"Makefile",
		"CMakeLists.txt",
		"pyproject.toml",
		"requirements.txt",
		"build.gradle",
		"pom.xml",
	}

	for _, marker in ipairs(markers) do
		if vim.fn.filereadable(cwd .. "/" .. marker) == 1 or vim.fn.isdirectory(cwd .. "/" .. marker) == 1 then
			return cwd
		end
	end

	local max_depth = 5
	local depth = 0
	while cwd ~= "/" and depth < max_depth do
		cwd = vim.fn.fnamemodify(cwd, ":h")
		for _, marker in ipairs(markers) do
			if vim.fn.filereadable(cwd .. "/" .. marker) == 1 or vim.fn.isdirectory(cwd .. "/" .. marker) == 1 then
				return cwd
			end
		end
		depth = depth + 1
	end

	return vim.fn.getcwd()
end

-- 使用 fd 搜索文件（修正版）
local function fd_find_files(root)
	-- 如果没有 fd，直接警告
	if vim.fn.executable("fd") ~= 1 then
		vim.notify("未检测到 fd 命令，请先安装：brew install fd", vim.log.levels.WARN)
		return {}
	end

	local patterns = {
		"target/debug/*",
		"target/release/*",
		"*.exe",
		"*.elf",
		"*.out",
		"*.bin",
		"*.py",
		"*.go",
		"*.js",
	}

	local files = {}

	for _, pattern in ipairs(patterns) do
		-- 使用 --glob 明确启用 glob 模式
		local cmd = "cd " .. vim.fn.shellescape(root) .. ' && fd --type f --glob "' .. pattern .. '"'

		local result = vim.fn.systemlist(cmd)

		for _, f in ipairs(result or {}) do
			if f ~= "" then
				table.insert(files, f)
			end
		end
	end

	return files
end

-- 同步选择调试文件（使用 vim.ui.select）
function M.select_debug_file()
	local root = find_project_root()
	local files = fd_find_files(root)

	if #files == 0 then
		vim.notify("未找到可调试文件，没有可执行文件", vim.log.levels.WARN)
		return nil
	end

	table.sort(files, function(a, b)
		local at = vim.fn.getftime(root .. "/" .. a)
		local bt = vim.fn.getftime(root .. "/" .. b)
		return at > bt
	end)

	-- 使用 vim.ui.select 进行异步选择
	local selected_file = nil
	local choice_made = false

	local select_items = {}
	for _, file in ipairs(files) do
		table.insert(select_items, {
			display = file,
			value = file,
		})
	end

	vim.ui.select(select_items, {
		prompt = "请选择调试文件:",
		format_item = function(item)
			return item.display
		end,
	}, function(choice)
		if choice then
			selected_file = root .. "/" .. choice.value
		end
		choice_made = true
	end)

	-- 等待用户选择完成
	while not choice_made do
		vim.wait(50)
	end

	return selected_file
end

-- 给 DAP 调用的接口
function M.option()
	return M.select_debug_file()
end

return M
