-- LSP 配置模块主入口
-- 整合了 LSP 客户端配置、自动命令、工具函数等功能
local M = {}

function M.setup()
	-- 初始化配置模块
	require("lsp.config").setup()

	-- 设置自动命令
	require("lsp.config").setup_autocmds()

	-- 初始化管理器
	require("lsp.manager").setup()

	-- 注册用户命令
	M._register_commands()
end

-- =============================================
-- 命令注册函数
-- =============================================

function M._register_commands()
	local config = require("lsp.config")
	local manager = require("lsp.manager")

	-- LSP 客户端管理命令
	vim.api.nvim_create_user_command("LspRestart", config.restart_lsp, { desc = "重启 LSP 客户端" })
	vim.api.nvim_create_user_command("LspStop", config.stop_lsp, { desc = "停止 LSP 客户端" })

	-- 诊断相关命令
	vim.api.nvim_create_user_command(
		"LspDiagnostics",
		config.open_all_diagnostics,
		{ desc = "打开项目诊断列表" }
	)
	vim.api.nvim_create_user_command(
		"LspBufferDiagnostics",
		config.open_buffer_diagnostics,
		{ desc = "打开当前缓冲区诊断列表" }
	)
	vim.api.nvim_create_user_command(
		"LspCopyError",
		config.copy_error_message,
		{ desc = "复制当前光标处的错误信息" }
	)

	-- 状态查询命令
	vim.api.nvim_create_user_command("LspStatus", manager.show_lsp_status, { desc = "显示 LSP 状态信息" })
	vim.api.nvim_create_user_command("LspInfo", manager.show_lsp_info, { desc = "显示详细的 LSP 信息" })
	vim.api.nvim_create_user_command("LspStats", manager.show_diagnostics_stats, { desc = "显示诊断统计" })
end

-- 按功能域分组导出，避免命名冲突
M.diagnostics = {
	open_all = require("lsp.config").open_all_diagnostics,
	open_buffer = require("lsp.config").open_buffer_diagnostics,
	copy_error = require("lsp.config").copy_error_message,
}

M.utils = {
	format_buffer = require("lsp.utils").format_buffer,
	get_active_lsps = require("lsp.utils").get_active_lsps,
	get_lsp_config = require("lsp.utils").get_lsp_config,
}

return M
