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
  local manager = require("lsp.manager")

  vim.api.nvim_create_user_command("LspStop", config.stop_lsp, { desc = "停止 LSP 客户端" })
  vim.api.nvim_create_user_command("LspStart", config.start_lsp, { desc = "启动 LSP 客户端" })
  vim.api.nvim_create_user_command("LspRestart", config.restart_lsp, { desc = "重启 LSP 客户端" })
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
end

return M
