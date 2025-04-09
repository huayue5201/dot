local M = {}

--- 获取 Rust 项目中最新的 ELF 可执行文件路径（用于 probe-rs）
function M.get_rust_program_binary()
	local function find_project_root()
		local cwd = vim.fn.getcwd()
		while cwd ~= "/" do
			if vim.fn.filereadable(cwd .. "/Cargo.toml") == 1 then
				return cwd
			end
			cwd = vim.fn.fnamemodify(cwd, ":h")
		end
		return nil
	end

	local project_root = find_project_root()
	if not project_root then
		vim.notify("[program_binary] 当前不在 Rust 项目中，跳过 ELF 获取", vim.log.levels.WARN)
		return nil
	end

	local metadata_json = vim.fn.system({
		"cargo",
		"metadata",
		"--format-version=1",
		"--no-deps",
	}, project_root)

	local ok, metadata = pcall(vim.fn.json_decode, metadata_json)
	if not ok then
		vim.notify("[program_binary] cargo metadata 解析失败: " .. metadata_json, vim.log.levels.ERROR)
		return nil
	end

	local target_dir = metadata.target_directory
	local target_triple = "thumbv7em-none-eabihf"
	local build_mode = "debug"

	local scan_dir = string.format("%s/%s/%s", target_dir, target_triple, build_mode)

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

--- 包装一层，带错误处理（不会抛出 Lua 异常）
function M.safe_get_rust_program_binary()
	local ok, result = pcall(M.get_rust_program_binary)
	if not ok then
		vim.notify("[program_binary] 获取 ELF 路径失败: " .. result, vim.log.levels.ERROR)
		return nil
	end
	return result
end

return M
