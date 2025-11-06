-- LSP 配置模块主入口
local M = {}

function M.setup()
	-- 初始化配置模块
	require("lsp_config.opts").setup()

	-- 设置自动命令
	require("lsp_config.opts").setup_autocmds()

	-- 初始化管理器
	require("lsp_config.manager").setup()

	-- 注册用户命令
	M._register_commands()
end

-- =============================================
-- 命令注册函数
-- =============================================

function M._register_commands()
	local opts = require("lsp_config.opts")
	local manager = require("lsp_config.manager")

	-- LSP 客户端管理命令
	vim.api.nvim_create_user_command("LspRestart", opts.restart_lsp, { desc = "重启 LSP 客户端" })
	vim.api.nvim_create_user_command("LspStop", opts.stop_lsp, { desc = "停止 LSP 客户端" })
	vim.api.nvim_create_user_command("LspStart", opts.start_lsp, { desc = "启动 LSP 客户端" })

	-- 诊断相关命令
	vim.api.nvim_create_user_command("LspDiagnostics", opts.open_all_diagnostics, { desc = "打开项目诊断列表" })
	vim.api.nvim_create_user_command(
		"LspBufferDiagnostics",
		opts.open_buffer_diagnostics,
		{ desc = "打开当前缓冲区诊断列表" }
	)
	vim.api.nvim_create_user_command(
		"LspCopyError",
		opts.copy_error_message,
		{ desc = "复制当前光标处的错误信息" }
	)

	-- 状态查询命令
	vim.api.nvim_create_user_command("LspStatus", manager.show_lsp_status, { desc = "显示 LSP 状态信息" })
	vim.api.nvim_create_user_command("LspInfo", manager.show_lsp_info, { desc = "显示详细的 LSP 信息" })
	vim.api.nvim_create_user_command("LspStats", manager.show_diagnostics_stats, { desc = "显示诊断统计" })
end

-- 按功能域分组导出
M.diagnostics = {
	open_all = require("lsp_config.opts").open_all_diagnostics,
	open_buffer = require("lsp_config.opts").open_buffer_diagnostics,
	copy_error = require("lsp_config.opts").copy_error_message,
}

M.utils = {
	format_buffer = require("lsp_config.utils").format_buffer,
	get_active_lsps = require("lsp_config.utils").get_active_lsps,
	get_lsp_config = require("lsp_config.utils").get_lsp_config,
}

return M
