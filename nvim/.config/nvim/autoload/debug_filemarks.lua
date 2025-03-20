-- autoload/debug.lua
local M = {}

local filepath = vim.fn.stdpath("cache") .. "/debug_file.txt"

-- 保存 debug 文件路径
local save_debug_file = function()
	-- 确保文件夹存在
	local dir = vim.fn.fnamemodify(filepath, ":p:h")
	if vim.fn.isdirectory(dir) == 0 then
		vim.fn.mkdir(dir, "p") -- 如果文件夹不存在则创建
	end
	-- 创建并写入文件
	local file = io.open(filepath, "w")
	if file then
		file:write(vim.g.debug_file)
		file:close()
	end
end

-- 加载已保存的 debug 文件路径
M.load_debug_file = function()
	local file = io.open(filepath, "r")
	if file then
		local line = file:read("*line")
		file:close()
		if line and vim.fn.filereadable(line) == 1 then
			vim.g.debug_file = line
		end
		-- require("neo-tree.sources.manager").refresh("filesystem")
	end
end

-- 切换 debug 文件标记
M.toggle_debug_file = function()
	local file = vim.fn.expand("%:p") -- 获取当前文件的完整路径
	if file ~= "" then
		if vim.g.debug_file == file then
			vim.g.debug_file = nil
			print("Debug file removed!")
		else
			vim.g.debug_file = file
			print("Debug file set to: " .. file)
			require("neo-tree.sources.manager").refresh("filesystem")
		end
		-- 保存当前 debug 文件路径
		save_debug_file()
	else
		print("No file to mark!")
	end
end

return M
