local registry = require("env.registry")
local json_store = require("user.json_store")

local M = {}

-- 共用一个 JSON 文件存储环境配置和项目状态
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_states.json",
	default_data = {},
	auto_save = true,
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

	-- 保存环境配置到共享的状态文件
	local project_data = state_store:get(key) or {}
	project_data.env = name
	state_store:set(key, project_data)

	if env.apply then
		env.apply()
	end
end

function M.load_env_on_startup()
	auto_require_envs()
	local key = project_key()
	local project_data = state_store:get(key) or {}
	local selected_name = project_data.env

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

-- ========== 纯净的状态管理 API ==========

-- 设置状态值
function M.set_state(key, value)
	local pkey = project_key()
	local project_data = state_store:get(pkey) or {}

	-- 初始化 states 表
	if not project_data.states then
		project_data.states = {}
	end

	project_data.states[key] = value
	state_store:set(pkey, project_data)
end

-- 获取状态值
function M.get_state(key)
	local pkey = project_key()
	local project_data = state_store:get(pkey) or {}

	if project_data.states then
		return project_data.states[key]
	end
	return nil
end

-- 切换布尔状态
function M.toggle_state(key)
	local current = M.get_state(key)
	local new_value = not (current == true)
	M.set_state(key, new_value)
	return new_value
end

-- 删除状态
function M.delete_state(key)
	local pkey = project_key()
	local project_data = state_store:get(pkey) or {}

	if project_data.states then
		project_data.states[key] = nil
		state_store:set(pkey, project_data)
	end
end

-- 获取当前项目所有状态（用于调试）
function M.get_all_states()
	local pkey = project_key()
	local project_data = state_store:get(pkey) or {}
	return project_data.states or {}
end

return M
