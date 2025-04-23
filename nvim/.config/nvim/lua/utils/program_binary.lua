local M = {}

-- 检查文件是否存在
local function is_file(path)
	return vim.fn.filereadable(path) == 1
end

-- 查找项目根目录
local function find_project_root()
	local cwd = vim.fn.getcwd()
	while cwd ~= "/" do
		if is_file(cwd .. "/Cargo.toml") then
			return cwd, "rust"
		elseif is_file(cwd .. "/Makefile") or is_file(cwd .. "/CMakeLists.txt") then
			return cwd, "c"
		end
		cwd = vim.fn.fnamemodify(cwd, ":h")
	end
	return nil, "unknown"
end

-- 获取 Rust 项目的 ELF 文件
local function get_rust_elf(project_root)
	local metadata_json = vim.fn.system({ "cargo", "metadata", "--format-version=1", "--no-deps" }, project_root)
	local ok, metadata = pcall(vim.fn.json_decode, metadata_json)
	if not ok then
		vim.notify("[program_binary] cargo metadata 解析失败: " .. metadata_json, vim.log.levels.ERROR)
		return nil
	end

	local target_dir = metadata.target_directory
	local triple = "thumbv7em-none-eabihf" -- 可以根据需要修改
	local build_mode = "debug" -- 或者 "release"

	local scan_dir = string.format("%s/%s/%s", target_dir, triple, build_mode)

	local ok_scan, plenary = pcall(require, "plenary.scandir")
	if not ok_scan then
		vim.notify("[program_binary] 未找到 plenary，请安装 nvim-lua/plenary.nvim", vim.log.levels.ERROR)
		return nil
	end

	local elf_files = plenary.scan_dir(scan_dir, {
		depth = 2,
		add_dirs = false,
		search_pattern = ".*",
	})

	local candidates = vim.tbl_filter(function(path)
		return path:match("%.elf$") or not path:match("%.[a-zA-Z0-9]+$")
	end, elf_files)

	if #candidates == 0 then
		vim.notify("[program_binary] 未找到 ELF 文件于路径: " .. scan_dir, vim.log.levels.WARN)
		return nil
	end

	table.sort(candidates, function(a, b)
		return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
	end)

	return candidates[1]
end

-- 获取 C 项目的 ELF 文件
local function get_c_elf(project_root)
	local dirs = { project_root .. "/build", project_root }
	local ok_scan, plenary = pcall(require, "plenary.scandir")
	if not ok_scan then
		vim.notify("[program_binary] 未找到 plenary，请安装 nvim-lua/plenary.nvim", vim.log.levels.ERROR)
		return nil
	end

	local candidates = {}
	for _, dir in ipairs(dirs) do
		local elf_files = plenary.scan_dir(dir, {
			depth = 2,
			add_dirs = false,
			search_pattern = ".*%.elf$",
		})
		vim.list_extend(candidates, elf_files)
	end

	if #candidates == 0 then
		vim.notify("[program_binary] 未找到 ELF 文件于路径: " .. vim.inspect(dirs), vim.log.levels.WARN)
		return nil
	end

	table.sort(candidates, function(a, b)
		return vim.loop.fs_stat(a).mtime.sec > vim.loop.fs_stat(b).mtime.sec
	end)

	return candidates[1]
end

-- 自动识别项目类型并查找 ELF 文件
function M.get_program_binary()
	local project_root, project_type = find_project_root()
	if not project_root then
		vim.notify("[program_binary] 未找到项目根目录", vim.log.levels.WARN)
		return nil
	end

	if project_type == "rust" then
		return get_rust_elf(project_root)
	elseif project_type == "c" then
		return get_c_elf(project_root)
	else
		vim.notify("[program_binary] 不支持的项目类型: " .. project_type, vim.log.levels.WARN)
		return nil
	end
end

-- 包装一层，带错误处理（不会抛出 Lua 异常）
function M.safe_get_program_binary()
	local ok, result = pcall(M.get_program_binary)
	if not ok then
		vim.notify("[program_binary] 获取 ELF 路径失败: " .. result, vim.log.levels.ERROR)
		return nil
	end
	return result
end

return M
