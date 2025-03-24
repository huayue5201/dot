-- ~/.config/nvim/lua/plugins/debug_file_manager.lua
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
		vim.notify("❌ Failed to save debug file data!", vim.log.levels.ERROR)
	end
end

-- 加载当前项目的调试文件
local function load_debug_file()
	local data = read_debug_file_data()
	local project_root = get_project_root()
	local debug_file = data[project_root]

	if debug_file and vim.fn.filereadable(debug_file) == 1 then
		vim.g.debug_file = debug_file
		-- vim.notify("✅ Loaded debug file: " .. debug_file, vim.log.levels.INFO)
	else
		vim.g.debug_file = nil
	end
end

-- 切换调试文件（标记/取消标记）
M.toggle_debug_file = function()
	local project_root = get_project_root()
	local data = read_debug_file_data()

	if data[project_root] then
		-- 取消标记
		data[project_root] = nil
		vim.g.debug_file = nil
		vim.notify("🚫 Debug file unmarked for project: " .. project_root, vim.log.levels.WARN)
	else
		-- 获取当前文件路径
		local file = vim.fn.expand("%:p")
		if not is_valid_debug_file(file) then
			vim.notify("⚠️ Invalid debug file! Only ELF or BIN files are allowed.", vim.log.levels.ERROR)
			return
		end

		-- 标记调试文件
		data[project_root] = file
		vim.g.debug_file = file
		vim.notify("✅ Debug file set to: " .. file, vim.log.levels.INFO)
	end

	write_debug_file_data(data)
	require("neo-tree.sources.manager").refresh("filesystem")
end

-- 运行时自动加载当前项目的调试文件
load_debug_file()

-- 映射快捷键
vim.keymap.set("n", "<A-a>", M.toggle_debug_file, { noremap = true, silent = true })

return M
