local M = {}

-- 检查文件是否存在
local function is_file(path)
	return vim.fn.filereadable(path) == 1
end

-- 查找项目根目录
local function find_project_root()
	local cwd = vim.fn.getcwd()
	local project_files = {
		["rust"] = "Cargo.toml",
		["c"] = { "Makefile", "CMakeLists.txt" },
	}

	local max_depth = 100 -- 假设最大递归深度为100
	local depth = 0
	while cwd ~= "/" and depth < max_depth do
		depth = depth + 1
		for project_type, files in pairs(project_files) do
			if type(files) == "table" then
				for _, file in ipairs(files) do
					if is_file(cwd .. "/" .. file) then
						return cwd, project_type
					end
				end
			elseif is_file(cwd .. "/" .. files) then
				return cwd, project_type
			end
		end
		cwd = vim.fn.fnamemodify(cwd, ":h")
	end
	return nil, "unknown"
end

-- 生成文件类型匹配模式
local file_patterns = {
	elf = ".*%.elf$",
	hex = ".*%.hex$",
	bin = ".*%.bin$",
}

local function generate_file_patterns(file_types)
	local patterns = {}
	for _, file_type in ipairs(file_types) do
		local pattern = file_patterns[file_type]
		if pattern then
			table.insert(patterns, pattern)
		else
			vim.notify("[program_binary] 无效的文件类型: " .. file_type, vim.log.levels.ERROR)
			return nil
		end
	end
	return patterns
end

-- 通用的文件查找函数，支持多个文件类型
local function get_program_file(scan_dirs, patterns)
	local ok_scan, plenary = pcall(require, "plenary.scandir")
	if not ok_scan then
		vim.notify("[program_binary] 未找到 plenary，请安装 nvim-lua/plenary.nvim", vim.log.levels.ERROR)
		return nil
	end

	local candidates = {}
	for _, dir in ipairs(scan_dirs) do
		for _, pattern in ipairs(patterns) do
			local files = plenary.scan_dir(dir, {
				depth = 2,
				add_dirs = false,
				search_pattern = pattern,
			})
			vim.list_extend(candidates, files)
		end
	end

	if #candidates == 0 then
		vim.notify("[program_binary] 未找到指定文件于路径: " .. vim.inspect(scan_dirs), vim.log.levels.WARN)
		return nil
	end

	-- 按修改时间降序排序
	table.sort(candidates, function(a, b)
		return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
	end)

	return candidates[1]
end

-- 获取 Rust 项目的 ELF/HEX/BIN 文件（支持用户指定文件类型顺序）
local function get_rust_elf(project_root, file_types)
	local metadata_json = vim.fn.system({ "cargo", "metadata", "--format-version=1", "--no-deps" }, project_root)
	local ok, metadata = pcall(vim.fn.json_decode, metadata_json)
	if not ok then
		vim.notify("[program_binary] cargo metadata 解析失败: " .. metadata_json, vim.log.levels.ERROR)
		return nil
	end

	local target_dir = metadata.target_directory
	local triple = "thumbv7em-none-eabihf" -- 可以根据需要修改
	local build_mode = "debug" -- 或者 "release"
	local scan_dir = vim.fn.fnamemodify(string.format("%s/%s/%s", target_dir, triple, build_mode), ":p")

	-- 根据用户指定的文件类型顺序生成匹配模式
	local patterns = generate_file_patterns(file_types)
	if not patterns then
		return nil
	end

	-- 查找文件
	local found_file = get_program_file({ scan_dir }, patterns)
	if found_file then
		vim.notify(
			"[program_binary] 成功找到文件: " .. found_file .. "，文件类型: " .. file_types[1],
			vim.log.levels.INFO
		)
	end
	return found_file
end

-- 获取 C 项目的 ELF/HEX/BIN 文件（支持用户指定文件类型顺序）
local function get_c_elf(project_root, file_types)
	local dirs = { project_root .. "/build", project_root }

	-- 根据用户指定的文件类型顺序生成匹配模式
	local patterns = generate_file_patterns(file_types)
	if not patterns then
		return nil
	end

	-- 查找文件
	local found_file = get_program_file(dirs, patterns)
	if found_file then
		vim.notify(
			"[program_binary] 成功找到文件: " .. found_file .. "，文件类型: " .. file_types[1],
			vim.log.levels.INFO
		)
	end
	return found_file
end

-- 自动识别项目类型并查找 ELF/HEX/BIN 文件（支持用户自定义文件类型顺序）
function M.get_program_binary(...)
	local project_root, project_type = find_project_root()
	if not project_root then
		vim.notify("[program_binary] 未找到项目根目录", vim.log.levels.WARN)
		return nil
	end

	-- 用户必须指定文件类型顺序
	local file_types = { ... }
	if #file_types == 0 then
		vim.notify(
			"[program_binary] 必须指定查找的文件类型顺序，如：'elf', 'bin', 'hex'。",
			vim.log.levels.ERROR
		)
		return nil
	end

	if project_type == "rust" then
		return get_rust_elf(project_root, file_types)
	elseif project_type == "c" then
		return get_c_elf(project_root, file_types)
	else
		vim.notify("[program_binary] 不支持的项目类型: " .. project_type, vim.log.levels.WARN)
		return nil
	end
end

-- 包装一层，带错误处理（不会抛出 Lua 异常）
function M.safe_get_program_binary(...)
	local ok, result = pcall(M.get_program_binary, ...)
	if not ok then
		vim.notify("[program_binary] 获取文件路径失败: " .. result, vim.log.levels.ERROR)
		return nil
	end
	return result
end

return M
