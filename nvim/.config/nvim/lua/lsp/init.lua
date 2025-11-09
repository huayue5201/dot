-- lua/lsp/init.lua
-- LSP 配置模块主入口
local M = {}

function M.setup()
	-- 初始化配置模块
	require("lsp.config").setup()

	-- 注册用户命令
	M._register_commands()
end

-- =============================================
-- 命令注册函数
-- =============================================

function M._register_commands()
	local config = require("lsp.config")
	local control = require("lsp.control")
	local manager = require("lsp.manager")
	local project_state = require("lsp.project_state")

	-- 基本 LSP 命令
	vim.api.nvim_create_user_command("LspStop", control.stop_lsp, { desc = "停止当前缓冲区的 LSP" })
	vim.api.nvim_create_user_command("LspStart", control.start_lsp, { desc = "启动当前缓冲区的 LSP" })
	vim.api.nvim_create_user_command("LspRestart", control.restart_lsp, { desc = "重启所有 LSP" })

	-- 项目级 LSP 命令
	vim.api.nvim_create_user_command("LspProjectStop", control.project_stop_lsp, { desc = "在项目中禁用 LSP" })
	vim.api.nvim_create_user_command("LspProjectStart", control.project_start_lsp, { desc = "在项目中启用 LSP" })

	-- 诊断命令
	vim.api.nvim_create_user_command("LspDiagnostics", config.open_all_diagnostics, { desc = "打开项目诊断" })
	vim.api.nvim_create_user_command(
		"LspBufferDiagnostics",
		config.open_buffer_diagnostics,
		{ desc = "打开缓冲区诊断" }
	)

	-- 状态命令
	vim.api.nvim_create_user_command("LspStatus", manager.show_lsp_status, { desc = "显示 LSP 状态" })
	vim.api.nvim_create_user_command("LspStats", function()
		project_state.show_project_stats()
	end, { desc = "显示 LSP 统计" })

	vim.api.nvim_create_user_command("LspCleanup", function()
		local cleaned = project_state.cleanup_invalid_buffer_states()
		if cleaned == 0 then
			vim.notify("没有需要清理的无效状态", vim.log.levels.INFO)
		end
	end, { desc = "清理无效状态" })
end

return M
