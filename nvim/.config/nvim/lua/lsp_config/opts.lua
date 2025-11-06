-- LSP 核心配置模块
local M = {}

-- =============================================
-- 诊断配置
-- =============================================

function M.setup_diagnostics()
  vim.diagnostic.config({
    virtual_text = false,
    severity_sort = true,
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "󰅚 ",
        [vim.diagnostic.severity.WARN] = "󰀪 ",
        [vim.diagnostic.severity.HINT] = " ",
        [vim.diagnostic.severity.INFO] = " ",
      },
      linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
      numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
    },
    underline = true,
    update_in_insert = true,
  })
end

-- =============================================
-- 自动命令配置
-- =============================================

function M.setup_autocmds()
  local utils = require("lsp_config.utils")
  local manager = require("lsp_config.manager")
  local supported_filetypes = utils.get_supported_filetypes()

  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("LspFileTypeAuto", { clear = true }),
    desc = "根据文件类型和项目状态启动 LSP",
    pattern = supported_filetypes,
    callback = function()
      manager.start_eligible_lsps()
    end,
  })

  -- LSP 附加到缓冲区时的配置
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspAttach", { clear = true }),
    desc = "LSP 客户端附加到缓冲区时的配置",
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      local manager = require("lsp_config.manager")

      -- 检查该 LSP 是否在项目中被禁用
      if not manager.is_lsp_enabled(client.name) then
        vim.lsp.stop_client(args.data.client_id, true)
        return
      end

      M.setup_keymaps(args.buf) -- 设置 LSP 按键映射

      -- 启用文档颜色高亮
      vim.lsp.document_color.enable(true, 0, { style = "virtual" })

      -- 启用 LSP 折叠
      if client:supports_method("textDocument/foldingRange") then
        vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
      end

      -- 启用内联提示
      if client:supports_method("textDocument/inlayHint") then
        vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())
      end
    end,
  })

  -- LSP 从缓冲区分离时的清理
  vim.api.nvim_create_autocmd("LspDetach", {
    group = vim.api.nvim_create_augroup("LspStopAndUnmap", { clear = true }),
    desc = "LSP 客户端分离时移除键映射",
    callback = function(args)
      M.remove_keymaps(args.buf)
    end,
  })

  -- 模式切换处理
  M.setup_mode_handlers()
end

-- =============================================
-- 模式切换处理
-- =============================================

function M.setup_mode_handlers()
  -- 插入/选择模式禁用/启用诊断
  vim.api.nvim_create_autocmd("ModeChanged", {
    pattern = { "n:i", "v:s", "i:n" },
    desc = "插入/选择模式禁用/启用诊断",
    callback = function()
      local bufnr = vim.api.nvim_get_current_buf()
      local diag_enabled = vim.diagnostic.is_enabled({ bufnr = bufnr })
      if diag_enabled then
        vim.diagnostic.enable(false, { bufnr = bufnr })
        vim.api.nvim_create_autocmd("ModeChanged", {
          pattern = { "i:n", "s:v" },
          once = true,
          desc = "离开插入/选择模式后重新启用诊断",
          callback = function()
            local current_buf = vim.api.nvim_get_current_buf()
            if vim.api.nvim_buf_is_valid(current_buf) then
              vim.diagnostic.enable(true, { bufnr = current_buf })
            end
          end,
        })
      end
    end,
  })

  -- 插入模式下禁用内联提示
  vim.api.nvim_create_autocmd("InsertEnter", {
    desc = "插入模式禁用内联提示",
    callback = function(args)
      local filter = { bufnr = args.buf }
      local inlay_hint = vim.lsp.inlay_hint
      if inlay_hint.is_enabled(filter) then
        inlay_hint.enable(false, filter)
        vim.api.nvim_create_autocmd("InsertLeave", {
          once = true,
          desc = "离开插入模式重新启用内联提示",
          callback = function()
            inlay_hint.enable(true, filter)
          end,
        })
      end
    end,
  })
end

-- =============================================
-- 按键映射配置
-- =============================================

local keymaps = {
  {
    "<leader>lw",
    "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>",
    "列出工作区文件夹",
  },
  {
    "<leader>toi",
    "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>",
    "打开/关闭内联提示",
  },
}

function M.setup_keymaps(bufnr)
  for _, map in ipairs(keymaps) do
    vim.keymap.set("n", map[1], map[2], {
      noremap = true,
      silent = true,
      desc = map[3],
      buffer = bufnr,
    })
  end
end

function M.remove_keymaps(bufnr)
  for _, map in ipairs(keymaps) do
    pcall(vim.keymap.del, "n", map[1], { buffer = bufnr })
  end
end

-- =============================================
-- 诊断工具函数
-- =============================================

function M.open_all_diagnostics()
  vim.diagnostic.setqflist({
    open = true,
    title = "项目诊断",
    severity = { min = vim.diagnostic.severity.WARN },
    format = function(d)
      return string.format(
        "[%s] %s (%s:%d)",
        vim.diagnostic.severity[d.severity],
        d.message,
        d.source or "?",
        d.lnum + 1
      )
    end,
  })
end

function M.open_buffer_diagnostics()
  vim.diagnostic.setloclist({
    open = true,
    title = "缓冲区诊断",
    severity = { min = vim.diagnostic.severity.HINT },
    format = function(d)
      return string.format("[%s] %s (%s)", vim.diagnostic.severity[d.severity], d.message, d.source or "?")
    end,
  })
end

function M.copy_error_message()
  local row = unpack(vim.api.nvim_win_get_cursor(0)) - 1
  local diag = vim.diagnostic.get(0, { lnum = row })
  if #diag > 0 then
    local messages = {}
    for _, diagnostic in ipairs(diag) do
      local code = diagnostic.code or "无错误代码"
      local message = diagnostic.message or "无错误信息"
      table.insert(messages, message .. " [" .. code .. "]")
    end
    local all_messages = table.concat(messages, "\n")
    vim.fn.setreg("+", all_messages)
    print("错误信息已复制到剪贴板:\n" .. all_messages)
  else
    print("光标位置没有错误!")
  end
end

-- =============================================
-- LSP 客户端管理
-- =============================================

-- 重启当前缓冲区的 LSP 客户端
function M.restart_lsp()
  vim.lsp.stop_client(vim.lsp.get_clients(), true)
  vim.defer_fn(function()
    require("lsp_config.manager").start_eligible_lsps()
  end, 500)
end

-- 停止 LSP 客户端（交互选择）
function M.stop_lsp()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  if not clients or vim.tbl_isempty(clients) then
    vim.notify("当前缓冲区没有活跃的 LSP 客户端", vim.log.levels.INFO)
    return
  end

  -- 获取 LSP 名称列表
  local lsp_names = vim.tbl_map(function(c)
    return c.name
  end, clients)

  local manager = require("lsp_config.manager")

  vim.ui.select(lsp_names, {
    prompt = "选择要停止的 LSP 客户端 (Esc取消):",
  }, function(choice)
    if not choice then
      vim.notify("已取消停止 LSP", vim.log.levels.INFO)
      return
    end

    -- 停止客户端并更新项目状态
    manager.stop_lsp_client(choice)
    manager.set_lsp_state(choice, false)

    vim.notify("已停止 LSP: " .. choice, vim.log.levels.INFO)
  end)
end

-- 启动 LSP 客户端（交互选择）
function M.start_lsp()
  local manager = require("lsp_config.manager")
  local utils = require("lsp_config.utils")

  -- 获取当前文件类型支持的 LSP
  local supported_lsps = utils.get_lsp_name()

  -- 找出被禁用的 LSP
  local disabled_lsps = {}
  for _, lsp_name in ipairs(supported_lsps) do
    if not manager.is_lsp_enabled(lsp_name) then
      table.insert(disabled_lsps, lsp_name)
    end
  end

  if #disabled_lsps == 0 then
    vim.notify("没有需要启动的 LSP 客户端", vim.log.levels.INFO)
    return
  end

  vim.ui.select(disabled_lsps, {
    prompt = "选择要启动的 LSP 客户端 (Esc取消):",
  }, function(choice)
    if not choice then
      vim.notify("已取消启动 LSP", vim.log.levels.INFO)
      return
    end

    -- 更新状态并启动
    manager.set_lsp_state(choice, true)
    local success, err = pcall(vim.lsp.enable, choice, true)
    if success then
      vim.notify("已启动 LSP: " .. choice, vim.log.levels.INFO)
    else
      vim.notify("启动 LSP 失败: " .. choice .. "\n" .. tostring(err), vim.log.levels.ERROR)
    end
  end)
end

-- =============================================
-- 模块初始化
-- =============================================

function M.setup()
  M.setup_diagnostics()
end

return M
