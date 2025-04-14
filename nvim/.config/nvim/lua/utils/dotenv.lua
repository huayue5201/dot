local M = {}

-- 从 .env 读取 KEY=VAL 格式
local function load_env_file(file)
	local f = io.open(file, "r")
	if not f then
		return
	end
	for line in f:lines() do
		local key, val = line:match("^([%w_]+)%s*=%s*(.+)$")
		if key and val then
			vim.env[key] = val
		end
	end
	f:close()
end

-- 从 .env.lua 加载
local function load_env_lua(file)
	local ok, result = pcall(dofile, file)
	if not ok then
		vim.notify("Failed to load " .. file .. ": " .. result, vim.log.levels.WARN)
	end
end

-- 主函数：自动加载 ~/.env 和 ~/.env.lua（如果存在）
function M.load()
	local home = vim.env.HOME
	local env_lua = home .. "/.env.lua"
	local env_file = home .. "/.env"

	if vim.fn.filereadable(env_file) == 1 then
		load_env_file(env_file)
	end

	if vim.fn.filereadable(env_lua) == 1 then
		load_env_lua(env_lua)
	end
end

return M
