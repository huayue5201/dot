-- utils/project_lsp.lua
local json_store = require("utils.json_store")

local M = {}

-- 创建 JSON 存储实例
local state_store = json_store:new({
	file_path = vim.fn.stdpath("cache") .. "/project_lsp_states.json",
	default_data = {},
})

-- 获取当前项目标识（与芯片配置一致）
local function get_current_project_name()
	return vim.fn.fnamemodify(vim.fn.getcwd(), ":t")
end

-- 读取项目状态缓存（使用 json_store 的 load 方法）
local function load_project_states()
	return state_store:load()
end

-- 保存项目状态到缓存文件（使用 json_store 的 save 方法）
local function save_project_states(states)
	return state_store:save(states)
end

-- 获取当前项目的 LSP 状态
function M.get_lsp_state()
	local project_name = get_current_project_name()
	local states = load_project_states()

	-- 如果项目状态未设置，返回默认值（true）
	if states[project_name] == nil then
		return true
	end

	return states[project_name]
end

-- 设置当前项目的 LSP 状态
function M.set_lsp_state(enabled)
	local project_name = get_current_project_name()
	local states = load_project_states()
	states[project_name] = enabled
	save_project_states(states)
end

-- 初始化 LSP 状态
function M.init()
	vim.g.lsp_enabled = M.get_lsp_state()
end

return M
