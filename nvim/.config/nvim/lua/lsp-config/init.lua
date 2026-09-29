-- lua/lsp-config/init.lua
---@brief lsp-config 入口：只负责编排各子模块
local M = {}

function M.setup()
	require("lsp-config.capabilities").setup() -- 全局 capabilities / root_markers
	require("lsp-config.diagnostics").setup() -- 诊断 UI
	require("lsp-config.autocmds").setup() -- 所有 autocmd（含 FileType 启停 / LspAttach）
	require("lsp-config.keys").global() -- 全局按键映射
end

return M
