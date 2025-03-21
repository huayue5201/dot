-- ~/.config/nvim/lua/plugins/debug_file_manager.lua

local filepath = vim.fn.stdpath("cache") .. "/debug_file.txt"

-- 检查并确保目录存在
local ensure_directory_exists = function(path)
	local dir = vim.fn.fnamemodify(path, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p") -- 如果文件夹不存在则创建
	end
end

-- 创建并写入文件，直接覆盖之前的记录
local save_debug_file = function()
	-- 检查 vim.g.debug_file 是否为 nil 或空字符串
	if not vim.g.debug_file or vim.g.debug_file == "" then
		print("No debug file to save!")
		return
	end

	-- 确保文件夹存在
	ensure_directory_exists(filepath)

	-- 创建并写入文件
	local file = io.open(filepath, "w")
	if file then
		file:write(vim.g.debug_file)
		file:close()
		print("Debug file saved: " .. vim.g.debug_file)
	else
		print("Failed to open debug file for writing!")
	end
end

-- 加载已保存的 debug 文件路径
local load_debug_file = function()
	local file = io.open(filepath, "r")
	if file then
		local line = file:read("*line")
		file:close()
		if line and vim.fn.filereadable(line) == 1 then
			vim.g.debug_file = line
		end
	end
end

-- 设置 debug 文件路径
local set_debug_file = function(file)
	vim.g.debug_file = file
	print("Debug file set to: " .. file)
end

-- 切换 debug 文件标记
local toggle_debug_file = function()
	local file = vim.fn.expand("%:p") -- 获取当前文件的完整路径
	if file ~= "" then
		set_debug_file(file) -- 设置或覆盖 debug 文件标记
		save_debug_file() -- 保存 debug 文件路径
		-- 刷新 UI
		require("neo-tree.sources.manager").refresh("filesystem")
	else
		print("No file to mark!")
	end
end

-- 自动加载已保存的 debug 文件路径
load_debug_file()

-- 映射调试文件切换功能
vim.keymap.set("n", "<A-a>", function()
	toggle_debug_file()
end, { noremap = true, silent = true })
