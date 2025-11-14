local registry = require("env.registry")
local json_store = require("utils.json_store")

local M = {}

-- 缓存实例
local env_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/selected_env.json",
	default_data = {},
	auto_save = false,
})

vim.api.nvim_set_hl(0, "env_icon", { fg = "#6B8E23", bold = true })

-- 自动加载 config 下的环境模块
local function auto_require_envs()
	local path = vim.fn.stdpath("config") .. "/lua/env/config/"
	for _, file in ipairs(vim.fn.glob(path .. "*.lua", false, true)) do
		local name = file:sub(#path + 1, -5)
		local ok, err = pcall(require, "env.config." .. name)
		if not ok then
			vim.notify("加载环境模块失败: " .. name .. "\n" .. err, vim.log.levels.WARN)
		end
	end
end

local function project_key()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

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
	vim.defer_fn(function()
		env_store:flush()
	end, 100)
end

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
		apply_env(detected_name, key)
		return
	end

	vim.g.envCofnig = registry.envs.default or { name = "Unknown", type = "generic" }
end

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
		end
	end)
end

function M.EnvStatus()
	local env = vim.g.envCofnig
	local name = (env and env.name) or "Unknown"
	return "%#env_icon# %*" .. name
end

return M
