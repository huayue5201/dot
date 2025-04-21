local M = {}

-- 读取 KEY=VAL 格式的 .env 文件，支持 export 和注释
local function load_env_file(file)
	local f = io.open(file, "r")
	if not f then
		return
	end

	for line in f:lines() do
		-- 忽略注释或空行
		if not line:match("^%s*#") and line:match("%S") then
			-- 匹配 export KEY=VAL 或 KEY=VAL
			local key, val = line:match("^%s*export%s+([%w_]+)%s*=%s*(.+)%s*$")
			if not key then
				key, val = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
			end
			if key and val then
				vim.env[key] = val
			end
		end
	end

	f:close()
end

-- 读取 .env.lua 文件，支持返回 table 自动注入 vim.env
local function load_env_lua(file)
	local ok, result = pcall(dofile, file)
	if not ok then
		vim.notify("Failed to load " .. file .. ": " .. result, vim.log.levels.WARN)
		return
	end

	if type(result) == "table" then
		for k, v in pairs(result) do
			if type(k) == "string" and type(v) == "string" then
				vim.env[k] = v
			end
		end
	end
end

-- 主入口函数：加载 ~/.env 和 ~/.config/nvim/.env.lua
function M.load()
	local home = vim.env.HOME
	local config_path = vim.fn.stdpath("config")
	local env_file = home .. "/.env"
	local env_lua = config_path .. "/.env.lua"

	if vim.fn.filereadable(env_file) == 1 then
		load_env_file(env_file)
	end

	if vim.fn.filereadable(env_lua) == 1 then
		load_env_lua(env_lua)
	end
end

return M
