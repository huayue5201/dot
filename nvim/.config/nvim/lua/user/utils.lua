-- /user/utils.lua
local M = {}

-- 查找项目的根目录
-- @param root_files table 包含可能的项目根文件的列表
-- @return string 项目的根目录或nil
function M.find_root_dir(root_files)
	local current_dir = vim.fn.getcwd()
	local root_dir = nil
	-- 检查当前工作目录是否包含潜在的项目根文件
	for _, file in ipairs(root_files) do
		local found = vim.fn.findfile(file, current_dir)
		if found ~= "" then
			root_dir = vim.fn.fnamemodify(found, ":h") -- 找到根文件，返回根目录
			break
		end
	end
	-- 如果当前工作目录没有包含根文件，则继续查找上层目录
	if not root_dir then
		local upper_dir = current_dir
		repeat
			for _, file in ipairs(root_files) do
				local path = upper_dir .. "/" .. file
				if vim.fn.filereadable(path) == 1 then
					root_dir = upper_dir -- 找到根目录，返回
					break
				end
			end
			if root_dir then
				break
			end
			upper_dir = vim.fn.fnamemodify(upper_dir, ":h") -- 上层目录
		until upper_dir == "/"
	end
	return root_dir
end

-- 重用现有的 LSP 客户端
-- @param client table 当前的 LSP 客户端
-- @param conf table LSP 配置
-- @return boolean 是否重用现有的 LSP 客户端
function M.reuse_client(client, conf)
	return client.name == conf.name and (client.config.root_dir == conf.root_dir or conf.root_dir == nil)
end

return M
