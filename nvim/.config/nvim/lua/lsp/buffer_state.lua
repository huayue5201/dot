-- lua/lsp/buffer_state.lua
-- 缓冲区级 LSP 状态管理模块（代理到 project_state.lua）
local project_state = require("lsp.project_state")

local M = {}

-- 代理所有函数到 project_state
function M.set_buffer_lsp_state(bufnr, lsp_name, enabled)
	return project_state.set_buffer_lsp_state(bufnr, lsp_name, enabled)
end

function M.get_buffer_lsp_state(bufnr, lsp_name)
	return project_state.get_buffer_lsp_state(bufnr, lsp_name)
end

function M.get_all_buffer_states(bufnr)
	return project_state.get_all_buffer_states(bufnr)
end

function M.cleanup_buffer_state(bufnr)
	return project_state.cleanup_buffer_state(bufnr)
end

function M.get_disabled_lsps_for_buffer(bufnr)
	return project_state.get_disabled_lsps_for_buffer(bufnr)
end

-- 新增：获取项目缓冲区状态
function M.get_project_buffer_states()
	return project_state.get_project_buffer_states()
end

-- 新增：清理无效状态
function M.cleanup_invalid_buffer_states()
	return project_state.cleanup_invalid_buffer_states()
end

return M
