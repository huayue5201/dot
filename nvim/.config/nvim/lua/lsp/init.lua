-- LSP 配置模块主入口
-- 负责模块初始化、命令注册和对外接口暴露
local M = {}

function M.setup()
	-- 初始化配置模块
	require("lsp.config").setup()

	-- 初始化管理器模块
	-- require("lsp.manager").setup()

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

	vim.api.nvim_create_user_command("LspStop", control.stop_lsp, { desc = "停止 LSP 客户端" })
	vim.api.nvim_create_user_command("LspStart", control.start_lsp, { desc = "启动 LSP 客户端" })
	vim.api.nvim_create_user_command("LspRestart", control.restart_lsp, { desc = "重启 LSP 客户端" })

	-- 缓冲区级程序化命令（主要用于调试）
	vim.api.nvim_create_user_command("LspBufferStop", function(opts)
		if opts.args and opts.args ~= "" then
			local lsp_names = vim.split(opts.args, "%s+")
			control.buffer_stop(lsp_names)
		else
			control.buffer_stop_all()
		end
	end, { desc = "停止当前缓冲区的 LSP", nargs = "*" })

	vim.api.nvim_create_user_command("LspBufferStart", function(opts)
		if opts.args and opts.args ~= "" then
			local lsp_names = vim.split(opts.args, "%s+")
			control.buffer_start(lsp_names)
		else
			control.buffer_start_all()
		end
	end, { desc = "启动当前缓冲区的 LSP", nargs = "*" })

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

	-- 新增的状态管理命令
	vim.api.nvim_create_user_command("LspProjectStats", function()
		project_state.show_project_stats()
	end, { desc = "显示项目 LSP 状态统计" })

	vim.api.nvim_create_user_command("LspCleanupInvalid", function()
		local cleaned = project_state.cleanup_invalid_buffer_states()
		if cleaned == 0 then
			vim.notify("没有需要清理的无效状态", vim.log.levels.INFO)
		end
	end, { desc = "清理无效的缓冲区状态" })
end

return M
