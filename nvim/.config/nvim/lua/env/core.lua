local registry = require("env.registry")
local json_store = require("utils.json_store")

local M = {}

-- JSON 缓存实例（每个项目保存选择的环境名称）
local env_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/selected_env.json",
	default_data = {},
})

-- 初始化状态栏高亮，只执行一次
vim.api.nvim_set_hl(0, "EnvIcon", { fg = "#6B8E23", bold = true })

-- 获取 env_config 目录路径
local function get_env_config_path()
	local ok, path = pcall(debug.getinfo, 1, "S")
	if ok and path then
		path = path.source:match("@(.*)/")
		if path then
			return path .. "env_config/"
		end
	end
	-- fallback
	return vim.fn.stdpath("config") .. "/lua/env/env_config/"
end

-- 自动加载 env_config 目录下所有模块
local function auto_require_envs()
	local base_path = get_env_config_path()
	for _, file in ipairs(vim.fn.glob(base_path .. "*.lua", false, true)) do
		local module_name = file:sub(#base_path + 1, -5) -- 去掉 .lua
		local ok, err = pcall(require, "env.env_config." .. module_name)
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

-- 启动加载环境（只存名称）
function M.load_env_on_startup()
	auto_require_envs()

	local key = project_key()
	local selected_name = env_store:get(key)

	if selected_name and registry.envs[selected_name] then
		vim.g.envCofnig = registry.envs[selected_name]
		return
	end

	local detected_name = registry.auto_detect_env()
	if detected_name and registry.envs[detected_name] then
		vim.g.envCofnig = registry.envs[detected_name]
		env_store:set(key, detected_name)
		if registry.envs[detected_name].apply then
			registry.envs[detected_name].apply()
		end
		return
	end

	vim.g.envCofnig = registry.envs.default or { name = "Unknown", type = "generic" }
end

-- 用户手动选择环境
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
		if choice and registry.envs[choice] then
			vim.g.envCofnig = registry.envs[choice]
			env_store:set(key, choice)
			if registry.envs[choice].apply then
				registry.envs[choice].apply()
			end
			vim.notify(("已选择环境: %s"):format(choice), vim.log.levels.INFO)
		end
	end)
end

-- 状态栏显示当前活跃环境
function M.EnvStatus()
	local env = vim.g.envCofnig
	local name = (env and env.name) or "Unknown"
	return "%#EnvIcon# %*" .. name
end

return M
