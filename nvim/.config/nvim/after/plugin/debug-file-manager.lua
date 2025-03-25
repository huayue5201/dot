local M = {}

local debug_file_storage = vim.fn.stdpath("cache") .. "/debug_files.json"

-- 获取当前项目的根目录
local function get_project_root()
	return vim.fn.getcwd()
end

-- 允许 ELF/BIN 文件或者 Rust 生成的可执行 ELF 文件
local function is_valid_debug_file(file)
	-- 先检查后缀名
	if file:match("%.elf$") or file:match("%.bin$") then
		return true
	end

	-- 使用 `file` 命令检查是否是 ELF 格式
	local output = vim.fn.system("file -b " .. vim.fn.shellescape(file))
	if output:match("ELF") then
		return true
	end

	return false
end

-- 获取文件的最后修改时间（用于比较文件是否修改）
local function get_file_mtime(file)
	return vim.fn.getftime(file)
end

-- 读取调试文件数据
local function read_debug_file_data()
	local file = io.open(debug_file_storage, "r")
	if not file then
		return {}
	end
	local content = file:read("*a")
	file:close()
	local ok, data = pcall(vim.fn.json_decode, content)
	return ok and data or {}
end

-- 写入调试文件数据（格式化 JSON）
local function write_debug_file_data(data)
	local file = io.open(debug_file_storage, "w")
	if file then
		local formatted_json = vim.fn.json_encode(data):gsub(",", ",\n    "):gsub("{", "{\n    "):gsub("}", "\n}")
		file:write(formatted_json)
		file:close()
	else
		vim.notify("❌ 保存调试文件数据失败！", vim.log.levels.ERROR)
	end
end

-- 加载当前项目的调试文件
local function load_debug_file()
	local data = read_debug_file_data()
	local project_root = get_project_root()
	local debug_file = data[project_root] and data[project_root].file

	if debug_file and vim.fn.filereadable(debug_file) == 1 then
		vim.g.debug_file = debug_file
		-- vim.notify("✅ 加载调试文件: " .. debug_file, vim.log.levels.INFO)
	else
		vim.g.debug_file = nil
	end
end

-- 切换调试文件（标记/取消标记）
M.toggle_debug_file = function()
	local project_root = get_project_root()
	local data = read_debug_file_data()

	-- 获取当前文件路径
	local file = vim.fn.expand("%:p")

	-- 判断文件是否是有效的调试文件
	if not is_valid_debug_file(file) then
		-- 无效的调试文件，显示警告
		vim.notify(
			"⚠️ 该文件不是有效的调试文件！仅支持 ELF 或 BIN 文件。",
			vim.log.levels.ERROR
		)
		return
	end

	-- 先判断当前项目是否已经标记了调试文件
	if data[project_root] then
		local current_debug_file = data[project_root].file

		-- 如果当前标记文件有效，判断其是否与 JSON 中的数据匹配
		if vim.fn.filereadable(current_debug_file) == 1 then
			local current_mtime = get_file_mtime(current_debug_file)
			local json_mtime = data[project_root].mtime

			-- 文件修改时间对比
			if current_mtime == json_mtime then
				vim.notify("⚠️ 此项目已设置调试文件！", vim.log.levels.INFO)
				return
			else
				-- 如果文件修改过，进行覆盖更新
				data[project_root] = { file = current_debug_file, mtime = current_mtime }
				vim.g.debug_file = current_debug_file
				write_debug_file_data(data)
				require("neo-tree.sources.manager").refresh("filesystem")
				vim.notify("✅ 调试文件已更新: " .. current_debug_file, vim.log.levels.INFO)
				return
			end
		else
			-- 如果当前标记的文件无效
			vim.notify("⚠️ 当前调试文件无效！", vim.log.levels.ERROR)
			return
		end
	end

	-- 如果当前文件是有效的调试文件，进行标记
	local mtime = get_file_mtime(file)

	-- 标记调试文件
	data[project_root] = { file = file, mtime = mtime }
	vim.g.debug_file = file
	vim.notify("✅ 调试文件已设置: " .. file, vim.log.levels.INFO)
	write_debug_file_data(data)
	require("neo-tree.sources.manager").refresh("filesystem")
end

-- 运行时自动加载当前项目的调试文件
load_debug_file()

-- 映射快捷键
vim.keymap.set("n", "<A-a>", M.toggle_debug_file, { noremap = true, silent = true })

return M
