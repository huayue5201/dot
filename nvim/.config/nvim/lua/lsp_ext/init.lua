-- lua/lsp_ext/init.lua
---@brief lsp_ext 入口：只负责编排各子模块
--
-- 目录约定：
--   init.lua      只做编排（本文件）
--   registry / servers / state / icons / statusline   与具体 server 无关的基础设施
--   capabilities / diagnostics / autocmds / keys      全局行为（capabilities、诊断 UI、autocmd、键位）
--   panel.lua     LSP 控制面板（浮窗）
--   actions.lua   跨模块的用户动作（runnables、code lens、外部文档、重启 …）
--   features/     单个 LSP 能力的客户端实现（每个 feature 保持自包含，由 autocmds 挂接）
--     code_lens.lua          渲染 + 鼠标交互 + 执行
--     rust_macro_preview.lua rust-analyzer 宏展开预览
--     rust_ssr.lua           rust-analyzer 结构化搜索替换（experimental/ssr）
--     runnables.lua          可运行目标执行（子目录 runnables/<lang>.lua 按语言分发）
--     utf8_guard.lua         非法 UTF-8 广播守卫
--     external_docs.lua      外部文档（gro）
--     hover_scroll.lua       LSP hover 浮窗滚动（不进入浮窗）
local M = {}

function M.setup()
	require("lsp_ext.capabilities").setup() -- 全局 capabilities / root_markers
	require("lsp_ext.diagnostics").setup() -- 诊断 UI
	require("lsp_ext.autocmds").setup() -- 所有 autocmd（含 FileType 启停 / LspAttach）
	require("lsp_ext.keys").global() -- 全局按键映射
	require("lsp_ext.features.hover_scroll").setup() -- hover 浮窗不进入也能滚
	require("lsp_ext.panel").setup() -- :LspPanel 控制面板命令
end

return M
