-- ============================================================================
-- Neovim 环境变量加载器 (优化版)
-- 支持 .env / .env.lua / PATH 自动补全 / 安全加载
-- ============================================================================
local M = {}

-- 读取 KEY=VAL 格式的 .env 文件，支持 export、引号、注释
local function load_env_file(file)
	local f = io.open(file, "r")
	if not f then
		return
	end

	for line in f:lines() do
		if not line:match("^%s*#") and line:match("%S") then
			local key, val = line:match("^%s*export%s*([%w_]+)%s*=%s*(.+)%s*$")
			if not key then
				key, val = line:match("^%s*([%w_]+)%s*=%s*(.+)%s*$")
			end
			if key and val then
				val = val:gsub("^[\"'](.-)[\"']$", "%1")
				vim.env[key] = val
			end
		end
	end

	f:close()
end

-- 安全加载 .env.lua 文件
local function load_env_lua(file)
	local func, err = loadfile(file)
	if not func then
		vim.notify("Failed to parse " .. file .. ": " .. err, vim.log.levels.WARN)
		return
	end

	local ok, result = pcall(func)
	if not ok then
		vim.notify("Failed to execute " .. file .. ": " .. result, vim.log.levels.WARN)
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

-- 自动创建默认 .env 和 .env.lua 文件
local function create_default_env_files()
	local home = vim.env.HOME
	local config_path = vim.fn.stdpath("config")
	local env_file = home .. "/.env"
	local env_lua = config_path .. "/.env.lua"

	if vim.fn.filereadable(env_file) == 1 or vim.fn.filereadable(env_lua) == 1 then
		return
	end

	-- 创建 .env
	local f = io.open(env_file, "w")
	if f then
		f:write("# Default environment variables\n")
		f:write('MY_VAR="value"\n')
		f:write("ANOTHER_VAR=123\n")
		f:write("export FOO=bar\n")
		f:close()
	end

	-- 创建 .env.lua
	f = io.open(env_lua, "w")
	if f then
		f:write("return {\n")
		f:write("  MY_VAR = 'value',\n")
		f:write("  ANOTHER_VAR = '123',\n")
		f:write("  FOO = 'bar',\n")
		f:write("}\n")
		f:close()
	end
end

-- 自动补全 PATH，保证常用命令可被 LSP/DAP 找到
local function ensure_common_paths()
	local home = vim.env.HOME
	local paths = {
		-- "/opt/homebrew/bin",                                           -- macOS Homebrew
		-- home .. "/.local/bin",                                         -- 用户本地 bin
		vim.fn.system("npm config get prefix"):gsub("\n", "") .. "/bin", -- npm global
	}

	local valid_paths = {}
	for _, p in ipairs(paths) do
		if p and vim.fn.isdirectory(p) == 1 then
			table.insert(valid_paths, p)
		end
	end

	-- 拼接到现有 PATH 前面
	if #valid_paths > 0 then
		vim.env.PATH = table.concat(valid_paths, ":") .. ":" .. (vim.env.PATH or "")
	end
end

-- 主入口：支持自定义路径列表
function M.load(paths)
	local home = vim.env.HOME
	local config_path = vim.fn.stdpath("config")

	paths = paths or {
		home .. "/.env",
		config_path .. "/.env.lua",
	}

	if vim.fn.filereadable(paths[1]) == 0 and vim.fn.filereadable(paths[2]) == 0 then
		create_default_env_files()
	end

	for _, file in ipairs(paths) do
		if vim.fn.filereadable(file) == 1 then
			if file:match("%.lua$") then
				load_env_lua(file)
			else
				load_env_file(file)
			end
		end
	end

	-- 确保 PATH 正确
	ensure_common_paths()
end

return M
