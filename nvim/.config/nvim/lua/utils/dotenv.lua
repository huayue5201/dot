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

-- 自动创建 .env 和 .env.lua 文件
local function create_default_env_files()
	local home = vim.env.HOME
	local config_path = vim.fn.stdpath("config")
	local env_file = home .. "/.env"
	local env_lua = config_path .. "/.env.lua"

	-- 创建 .env 文件
	local f = io.open(env_file, "r")
	if not f then
		f = io.open(env_file, "w")
		if f then
			-- 写入默认内容
			f:write("# Default environment variables\n")
			f:write("MY_VAR=value\n")
			f:write("ANOTHER_VAR=123\n")
			f:write("export FOO=bar\n")
			f:close()
			vim.notify(".env file created at " .. env_file, vim.log.levels.INFO)
		end
	end

	-- 创建 .env.lua 文件
	f = io.open(env_lua, "r")
	if not f then
		f = io.open(env_lua, "w")
		if f then
			-- 写入默认 Lua 内容
			f:write("return {\n")
			f:write("  MY_VAR = 'value',\n")
			f:write("  ANOTHER_VAR = '123',\n")
			f:write("  FOO = 'bar',\n")
			f:write("}\n")
			f:close()
			vim.notify(".env.lua file created at " .. env_lua, vim.log.levels.INFO)
		end
	end
end

-- 主入口函数：加载 ~/.env 和 ~/.config/nvim/.env.lua
function M.load()
	local home = vim.env.HOME
	local config_path = vim.fn.stdpath("config")
	local env_file = home .. "/.env"
	local env_lua = config_path .. "/.env.lua"

	-- 如果文件不存在，自动创建
	create_default_env_files()

	if vim.fn.filereadable(env_file) == 1 then
		load_env_file(env_file)
	end

	if vim.fn.filereadable(env_lua) == 1 then
		load_env_lua(env_lua)
	end
end

return M
