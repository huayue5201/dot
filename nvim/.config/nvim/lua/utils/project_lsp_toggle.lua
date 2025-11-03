local json_store = require("utils.json_store")

local M = {}

-- 创建 JSON 存储实例（用于项目级 LSP 状态）
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
	auto_save = false, -- 采用延迟写入模式，避免频繁 I/O
})

-- 获取当前项目唯一标识（基于路径哈希）
local function get_current_project_id()
	local cwd = vim.fn.getcwd()
	local name = vim.fn.fnamemodify(cwd, ":t")
	local hash = vim.fn.sha256(cwd):sub(1, 8)
	return name .. "-" .. hash
end

-- 获取项目显示名（仅用于提示）
local function get_project_display_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 安全加载状态（支持 get_all）
local function load_project_states()
	if state_store.get_all then
		return state_store:get_all()
	end
	return state_store:load()
end

-- 延迟保存状态
local function save_project_states(states)
	state_store:save(states)
	vim.defer_fn(function()
		if state_store.flush then
			state_store:flush()
		end
	end, 100)
end

-- 获取当前项目 LSP 启用状态（默认为启用）
function M.get_lsp_state()
	local project_id = get_current_project_id()
	local states = load_project_states()
	local state = states[project_id]
	return state == nil or state.enabled
end

-- 设置当前项目的 LSP 启用 / 禁用状态
function M.set_lsp_state(enabled)
	local project_id = get_current_project_id()
	local project_name = get_project_display_name()
	local states = load_project_states()

	local lsp_utils = require("utils.lsp_utils")
	local lsp_name = lsp_utils.get_lsp_name and lsp_utils.get_lsp_name()

	if not lsp_name then
		vim.notify("No active LSP client found for this buffer", vim.log.levels.WARN)
		return
	end

	if type(lsp_name) == "table" then
		lsp_name = table.concat(lsp_name, ", ")
	end

	-- 状态未变化则跳过写入
	if states[project_id] and states[project_id].enabled == enabled then
		return
	end

	-- 更新状态缓存
	states[project_id] = {
		enabled = enabled,
		lsp_name = lsp_name,
		timestamp = os.time(),
	}

	save_project_states(states)
	vim.g.lsp_enabled = enabled

	vim.notify(
		string.format("LSP %s for project: %s [%s]", enabled and "enabled" or "disabled", project_name, lsp_name),
		vim.log.levels.INFO
	)
end

-- 初始化当前项目 LSP 状态（启动或切换项目时调用）
function M.init()
	local enabled = M.get_lsp_state()
	vim.g.lsp_enabled = enabled
end

return M
