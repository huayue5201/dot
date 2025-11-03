local registry = require("env.registry")
local json_store = require("utils.json_store")

local M = {}

-- JSON 缓存实例（每个项目保存选择的环境名称）
local env_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/selected_env.json",
	default_data = {},
	auto_save = false, -- 不立即写入，延迟保存
})

-- 初始化状态栏高亮
vim.api.nvim_set_hl(0, "EnvIcon", { fg = "#6B8E23", bold = true })

-- 获取 env_config 目录路径
local function get_env_config_path()
	local ok, path = pcall(debug.getinfo, 1, "S")
	if ok and path then
		path = path.source:match("@(.*)/")
		if path then
			return path .. "envSet/"
		end
	end
	return vim.fn.stdpath("config") .. "/lua/env/envSet/"
end

-- 自动加载 env_config 目录下所有模块
local function auto_require_envs()
	local base_path = get_env_config_path()
	for _, file in ipairs(vim.fn.glob(base_path .. "*.lua", false, true)) do
		local module_name = file:sub(#base_path + 1, -5) -- 去掉 .lua
		local ok, err = pcall(require, "env.envSet." .. module_name)
		if not ok then
			vim.notify("加载环境模块失败: " .. module_name .. "\n" .. err, vim.log.levels.WARN)
		end
	end
end

-- 唯一项目 key
local function project_key()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 应用并保存环境
local function apply_env(name, key)
	local env = registry.envs[name]
	if not env then
		return
	end

	vim.g.envCofnig = env
	env_store:set(key, name)

	if env.apply then
		env.apply()
	end

	-- 延迟写入到磁盘
	vim.defer_fn(function()
		env_store:flush()
	end, 100)
end

-- 启动时自动加载环境
function M.load_env_on_startup()
	auto_require_envs()
	local key = project_key()
	local selected_name = env_store:get(key)

	-- 1️⃣ 已保存环境
	if selected_name and registry.envs[selected_name] then
		vim.g.envCofnig = registry.envs[selected_name]
		return
	end

	-- 2️⃣ 自动检测
	local detected_name = registry.auto_detect_env()
	if detected_name and registry.envs[detected_name] then
		apply_env(detected_name, key)
		return
	end

	-- 3️⃣ 默认环境
	vim.g.envCofnig = registry.envs.default or { name = "Unknown", type = "generic" }
end

-- 手动选择环境
function M.choose_env()
	local key = project_key()
	local names = vim.tbl_keys(registry.envs)
	table.sort(names)

	vim.ui.select(names, {
		prompt = "选择环境",
		format_item = function(name)
			local env = registry.envs[name]
			return string.format("%s (%s)", env.name or name, env.type or "unknown")
		end,
	}, function(choice)
		if choice then
			apply_env(choice, key)
			vim.notify(("已选择环境: %s"):format(choice), vim.log.levels.INFO)
		end
	end)
end

-- 状态栏显示当前环境
function M.EnvStatus()
	local env = vim.g.envCofnig
	local name = (env and env.name) or "Unknown"
	return "%#EnvIcon# %*" .. name
end

return M
