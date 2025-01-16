-- lua/user/lsp_config_optimized.lua

local M = {}

-- 全局诊断配置（仅初始化一次）
local function setup_global_diagnostics()
  vim.diagnostic.config({
    virtual_text = {
      spacing = 4,
      source = "if_many",
      prefix = "■",
    },
    float = {
      source = "if_many",
      border = "rounded",
    },
    signs = {
      text = {
        [vim.diagnostic.severity.ERROR] = "✘",
        [vim.diagnostic.severity.WARN] = "▲",
        [vim.diagnostic.severity.HINT] = "⚑",
        [vim.diagnostic.severity.INFO] = "»",
      },
    },
    underline = true,
    update_in_insert = false,
    severity_sort = true,
  })

  vim.lsp.handlers["textDocument/hover"] = vim.lsp.with(vim.lsp.handlers.hover, { border = "single" })
  vim.lsp.handlers["textDocument/signatureHelp"] =
      vim.lsp.with(vim.lsp.handlers.signature_help, { border = "single" })
end

-- 设置按键映射
local function setup_keymaps(buf)
  local mappings = {
    { "n", "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" },
    { "n", "grn", "<cmd>lua vim.lsp.buf.rename()<cr>", "重命名" },
    { "n", "gra", "<cmd>lua vim.lsp.buf.code_action()<cr>", "代码建议" },
    { "n", "grr", "<cmd>lua vim.lsp.buf.references()<cr>", "跳转到引用" },
    { "n", "gri", "<cmd>lua vim.lsp.buf.implementation()<cr>", "跳转到实现" },
    { "n", "gO", "<cmd>lua vim.lsp.buf.document_symbol()<cr>", "代码符号" },
    { "n", "gd", "<cmd>lua vim.lsp.buf.definition()<cr>", "跳转到定义" },
    { "n", "grd", "<cmd>lua vim.lsp.buf.declaration()<cr>", "跳转到声明" },
    { "n", "grt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", "跳转到类型定义" },
    { "n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "显示函数签名帮助" },
    { "n", "<leader>wa", "<cmd>lua vim.lsp.buf.add_workspace_folder()<cr>", "添加工作区文件夹" },
    { "n", "<leader>wr", "<cmd>lua vim.lsp.buf.remove_workspace_folder()<cr>", "移除工作区文件夹" },
    { "n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>", "列出工作区文件夹" },
    { "n", "<leader>d", "<cmd>lua vim.diagnostic.enable(not vim.diagnostic.is_enabled())<cr>", "打开/关闭诊断功能" },
    { "n", "<leader>i", "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>", "开启/关闭内联提示" },
    { "n", "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" },
  }
  for _, map in ipairs(mappings) do
    vim.keymap.set(map[1], map[2], map[3], { noremap = true, silent = true, buffer = buf, desc = map[4] })
  end
end

-- 设置关键字高亮
local function setup_highlight_symbol(buf)
  local group = vim.api.nvim_create_augroup("highlight_symbol", { clear = false })

  vim.api.nvim_clear_autocmds({ buffer = buf, group = group })

  vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
    group = group,
    buffer = buf,
    callback = vim.lsp.buf.document_highlight,
  })

  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
    group = group,
    buffer = buf,
    callback = vim.lsp.buf.clear_references,
  })
end

-- 开启 CodeLens 刷新
local function setup_codelens_refresh(buf)
  local group = vim.api.nvim_create_augroup("codelens_refresh", { clear = false })

  vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
    group = group,
    buffer = buf,
    callback = function()
      vim.lsp.codelens.refresh({ bufnr = buf })
    end,
  })
end

-- LSP 主设置函数
M.lspSetup = function()
  setup_global_diagnostics() -- 全局诊断配置
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
    callback = function(args)
      local buf = args.buf
      setup_keymaps(buf)
      -- setup_highlight_symbol(buf) -- 高亮关键字
      setup_codelens_refresh(buf) -- 刷新 CodeLens
    end,
  })
end

return M
