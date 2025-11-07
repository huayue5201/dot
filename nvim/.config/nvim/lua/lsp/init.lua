-- LSP 配置模块主入口
-- 负责模块初始化、命令注册和对外接口暴露
local M = {}

function M.setup()
	-- 初始化配置模块
	require("lsp.config").setup()

	-- 初始化管理器模块
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
	local large_file = require("lsp.large_file")

	-- LSP 客户端管理命令
	vim.api.nvim_create_user_command("LspRestart", function()
		-- 先检查文件大小状态
		manager.restart_lsps_for_small_file()
		-- 然后重启 LSP
		config.restart_lsp()
	end, { desc = "重启 LSP 客户端（会重新检查文件大小）" })

	vim.api.nvim_create_user_command("LspStop", config.stop_lsp, { desc = "停止 LSP 客户端" })
	vim.api.nvim_create_user_command("LspStart", config.start_lsp, { desc = "启动 LSP 客户端" })

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

	-- 大文件检测相关命令
	vim.api.nvim_create_user_command("LspFileSizeInfo", function()
		local status = large_file.get_large_file_status()
		if status.status == "unknown" then
			print("无法获取文件信息")
		else
			local large_file_msg = status.is_large_file and " (大文件 - LSP 已禁用)" or ""
			print(string.format("文件大小: %s, 行数: %s%s", status.size_mb, status.lines_count, large_file_msg))

			if status.is_large_file then
				local reasons = {}
				if status.is_large_by_size then
					table.insert(reasons, string.format("超过大小阈值(%s)", status.threshold_mb))
				end
				if status.is_large_by_lines then
					table.insert(reasons, string.format("超过行数阈值(%s行)", status.threshold_lines))
				end
				print(string.format("原因: %s", table.concat(reasons, ", ")))
			end

			if #status.disabled_lsps > 0 then
				print(string.format("已禁用的 LSP: %s", table.concat(status.disabled_lsps, ", ")))
			end
		end
	end, { desc = "显示当前文件大小、行数和 LSP 状态" })
end

-- =============================================
-- 按功能域分组导出
-- =============================================

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
