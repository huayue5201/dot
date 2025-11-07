-- 项目级 LSP 状态管理模块
-- 负责管理不同项目中 LSP 的启用/禁用状态
local json_store = require("utils.json_store")

local M = {}

-- =============================================
-- 状态存储初始化
-- =============================================

-- 创建 JSON 存储实例（用于项目级 LSP 状态）
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
	auto_save = false,
})

-- =============================================
-- 项目标识管理
-- =============================================

-- 获取当前项目唯一标识
function M.get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- =============================================
-- 状态存储操作
-- =============================================

-- 安全加载状态
function M.load_project_states()
	if state_store.get_all then
		return state_store:get_all()
	end
	return state_store:load()
end

-- 延迟保存状态
function M.save_project_states(states)
	state_store:save(states)
	vim.defer_fn(function()
		if state_store.flush then
			state_store:flush()
		end
	end, 100)
end

-- =============================================
-- LSP 状态管理
-- =============================================

-- 检查特定 LSP 是否启用
function M.is_lsp_enabled(lsp_name)
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	local project_states = states[project_id]

	if not project_states or not project_states[lsp_name] then
		return true -- 默认启用
	end

	return project_states[lsp_name].enabled
end

-- 设置 LSP 启用状态
function M.set_lsp_state(lsp_name, enabled)
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()

	states[project_id] = states[project_id] or {}
	states[project_id][lsp_name] = {
		enabled = enabled,
		timestamp = os.time(),
	}

	M.save_project_states(states)

	vim.notify(string.format("LSP %s: %s", lsp_name, enabled and "已启用" or "已禁用"), vim.log.levels.INFO)
end

-- 获取当前项目所有 LSP 状态
function M.get_project_lsp_states()
	local project_id = M.get_current_project_id()
	local states = M.load_project_states()
	return states[project_id] or {}
end

return M
