-- LSP 配置管理模块
-- 负责诊断配置、自动命令、按键映射等配置相关功能
local M = {}

-- 延迟加载模块引用
local manager, project_state, utils

local function ensure_modules()
  if not manager then
    manager = require("lsp.manager")
  end
  if not project_state then
    project_state = require("lsp.project_state")
  end
  if not utils then
    utils = require("lsp.utils")
  end
end

-- 统一错误处理函数
local function handle_lsp_error(operation, lsp_name, err, level)
  level = level or vim.log.levels.ERROR
  local message = string.format("LSP %s %s: %s", lsp_name, operation, tostring(err))
  vim.notify(message, level)
  return false, err
end

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
  ensure_modules()
  local supported_filetypes = utils.get_supported_filetypes()

  -- 文件类型自动命令：根据文件类型启动 LSP
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

      -- 检查该 LSP 是否在项目中被禁用
      if not project_state.is_lsp_enabled(client.name) then
        local success, err = manager.stop_lsp(client.name, args.buf)
        if success then
          vim.notify(string.format("LSP %s 在项目中已禁用", client.name), vim.log.levels.INFO)
        else
          vim.notify(string.format("禁用 LSP %s 失败: %s", client.name, err), vim.log.levels.ERROR)
        end
        return
      end

      -- 设置按键映射
      M.setup_keymaps(args.buf)

      -- 启用文档颜色高亮
      vim.lsp.document_color.enable(true, 0, { style = "virtual" })

      -- 启用 LSP 折叠
      -- 已交给ufo插件
      -- if client:supports_method("textDocument/foldingRange") then
      --   vim.wo.foldexpr = "v:lua.vim.lsp.foldexpr()"
      -- end

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
    vim.fn.setreg("+", table.concat(messages, "\n"))
    print("错误信息已复制到剪贴板:\n" .. table.concat(messages, "\n"))
  else
    print("光标位置没有错误!")
  end
end

-- =============================================
-- LSP 客户端管理
-- =============================================

function M.restart_lsp()
  ensure_modules()
  local clients = vim.lsp.get_clients()

  -- 先停止所有客户端
  for _, client in ipairs(clients) do
    manager.stop_lsp(client.name)
  end
  -- 延迟重启
  vim.defer_fn(function()
    manager.start_eligible_lsps()
    vim.notify("LSP 客户端已重启", vim.log.levels.INFO)
  end, 500)
end

function M.stop_lsp()
  ensure_modules()
  local bufnr = vim.api.nvim_get_current_buf()
  local clients = vim.lsp.get_clients({ bufnr = bufnr })

  if not clients or vim.tbl_isempty(clients) then
    vim.notify("当前缓冲区没有活跃的 LSP 客户端", vim.log.levels.INFO)
    return
  end

  local lsp_names = vim.tbl_map(function(client)
    return client.name
  end, clients)

  vim.ui.select(lsp_names, { prompt = "  停止lsp " }, function(choice)
    if not choice then
      vim.notify("已取消停止操作", vim.log.levels.INFO)
      return
    end

    local success, err = manager.stop_lsp(choice, bufnr)
    if success then
      manager.set_lsp_state(choice, false)
      vim.notify("已停止 LSP: " .. choice, vim.log.levels.INFO)
    else
      handle_lsp_error("停止", choice, err)
    end
  end)
end

function M.start_lsp()
  ensure_modules()
  local disabled_lsps = {}

  for _, lsp_name in ipairs(utils.get_lsp_name()) do
    if not manager.is_lsp_enabled(lsp_name) then
      table.insert(disabled_lsps, lsp_name)
    end
  end

  if #disabled_lsps == 0 then
    vim.notify("所有支持的 LSP 客户端均已启动", vim.log.levels.INFO)
    return
  end

  vim.ui.select(disabled_lsps, { prompt = " 󰀚 启动lsp " }, function(choice)
    if not choice then
      vim.notify("已取消启动操作", vim.log.levels.INFO)
      return
    end

    local success, err = manager.start_lsp(choice)
    if success then
      manager.set_lsp_state(choice, true)
      vim.notify("已启动 LSP: " .. choice, vim.log.levels.INFO)
    else
      handle_lsp_error("启动", choice, err)
    end
  end)
end

-- =============================================
-- 模块初始化
-- =============================================

function M.setup()
  M.setup_diagnostics()
  M.setup_autocmds()
end

return M
