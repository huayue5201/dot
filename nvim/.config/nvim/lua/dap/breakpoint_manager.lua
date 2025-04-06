local M = {}

local debug_file_storage = vim.fn.stdpath("cache") .. "/debug_files.json"

-- 获取当前项目的根目录
local function get_project_root()
	return vim.fn.getcwd()
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
function M.write_debug_file_data(data)
	-- 如果数据为空，初始化为空 JSON 对象
	if vim.tbl_isempty(data) then
		data = {}
	end
	-- 使用 vim.fn.json_encode 格式化 JSON 数据（不传递额外的选项）
	local json_data = vim.fn.json_encode(data)

	-- 手动格式化 JSON 数据（缩进和换行）
	-- 添加换行符和缩进，使得 JSON 更加易读
	local formatted_json = json_data:gsub(",", ",\n    "):gsub("{", "{\n    "):gsub("}", "\n}")
	-- 写入文件
	local file = io.open(debug_file_storage, "w")
	if file then
		file:write(formatted_json)
		file:close()
	else
		vim.notify("❌ 保存调试文件数据失败！", vim.log.levels.ERROR)
	end
end

-- 清理无效的调试文件数据
local function clean_invalid_debug_files(data)
	local valid_data = {}

	-- 遍历所有项目根目录的数据，检查文件是否有效
	for project_root, project_data in pairs(data) do
		local debug_file = project_data.file

		-- 检查文件是否存在
		if vim.fn.filereadable(debug_file) == 1 then
			-- 文件存在，保留该数据
			valid_data[project_root] = project_data
		else
			-- 文件无效，打印提示
			vim.notify("⚠️ 无效调试文件已清理: " .. debug_file, vim.log.levels.INFO)
		end
	end

	return valid_data
end

-- 加载当前项目的调试文件
local function load_debug_file()
	local data = read_debug_file_data()
	local cleaned_data = clean_invalid_debug_files(data) -- 清理无效的调试文件

	local project_root = get_project_root()
	local debug_file = cleaned_data[project_root] and cleaned_data[project_root].file

	if debug_file and vim.fn.filereadable(debug_file) == 1 then
		vim.g.debug_file = debug_file
	else
		vim.g.debug_file = nil
	end

	-- 清理后，重新保存有效的数据
	M.write_debug_file_data(cleaned_data)
end

-- 切换调试文件（标记/取消标记）
M.toggle_debug_file = function()
	local project_root = get_project_root()
	local data = read_debug_file_data()

	-- 获取当前文件路径
	local file = vim.fn.expand("%:p")

	-- 判断当前项目是否已设置调试文件
	if data[project_root] then
		local current_debug_file = data[project_root].file

		-- 如果当前标记文件有效，检查是否与 JSON 中的数据一致
		if vim.fn.filereadable(current_debug_file) == 1 then
			local current_mtime = get_file_mtime(current_debug_file)
			local json_mtime = data[project_root].mtime

			-- 比较文件的修改时间
			if current_mtime == json_mtime then
				vim.notify("⚠️ 此项目已设置调试文件！", vim.log.levels.INFO)
				return
			else
				-- 如果文件修改过，更新数据
				data[project_root] = { file = current_debug_file, mtime = current_mtime }
				vim.g.debug_file = current_debug_file
				M.write_debug_file_data(data)
				require("neo-tree.sources.manager").refresh("filesystem")
				vim.notify("✅ 调试文件已更新: " .. current_debug_file, vim.log.levels.INFO)
				return
			end
		else
			-- 当前标记文件无效
			vim.notify("⚠️ 当前调试文件无效！", vim.log.levels.ERROR)
			return
		end
	end

	-- 如果当前文件有效，标记为调试文件
	local mtime = get_file_mtime(file)

	-- 设置新的调试文件
	data[project_root] = { file = file, mtime = mtime }
	vim.g.debug_file = file
	vim.notify("✅ 调试文件已设置: " .. file, vim.log.levels.INFO)
	M.write_debug_file_data(data)
	require("neo-tree.sources.manager").refresh("filesystem")
end

-- 运行时自动加载当前项目的调试文件
load_debug_file()

-- 映射快捷键
vim.keymap.set("n", "<localleader>b", M.toggle_debug_file, { silent = true, desc = "标记调试文件" })

return M
