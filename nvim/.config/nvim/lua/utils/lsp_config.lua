-- lua/user/lsp_config.lua

local M = {}

-- 设置全局按键映射（仅初始化一次）
local function setup_global_keymaps()
  local mappings = {
    { "n", "<leader>od", "<cmd>lua vim.diagnostic.setloclist()<cr>", "打开诊断列表" }, -- 打开当前缓冲区的诊断信息列表
    { "n", "<leader>ds", "<cmd>lua vim.diagnostic.setqflist()<cr>", "打开快速修复列表" }, -- 打开快速修复列表
    { "n", "<leader>cl", "<cmd>lua vim.lsp.stop_client(vim.lsp.get_clients())<cr>", "关闭LSP客户端" }, -- 停止所有LSP客户端
    { "n", "<leader>wl", "<cmd>lua print(vim.inspect(vim.lsp.buf.list_workspace_folders()))<cr>", "列出工作区文件夹" }, -- 列出工作区文件夹
  }

  -- 设置全局快捷键映射
  for _, map in ipairs(mappings) do
    -- 这些映射只需要初始化一次，可以放在 LspAttach 之前设置
    vim.keymap.set(map[1], map[2], map[3], { noremap = true, silent = true, desc = map[4] })
  end
end

-- 设置每个缓冲区的按键映射
local function setup_keymaps(buf)
  local mappings = {
    -- LSP相关操作映射
    { "n", "<leader>gd", "<cmd>lua vim.lsp.buf.definition()<cr>", "跳转到定义" }, -- 跳转到符号定义
    { "n", "<leader>gr", "<cmd>lua vim.lsp.buf.references()<cr>", "跳转到引用" }, -- 跳转到符号引用
    { "n", "<leader>gn", "<cmd>lua vim.lsp.buf.rename()<cr>", "重命名当前符号" }, -- 重命名符号
    { "n", "<leader>ga", "<cmd>lua vim.lsp.buf.code_action()<cr>", "触发代码操作" }, -- 触发代码建议或修复
    { "n", "<leader>gi", "<cmd>lua vim.lsp.buf.implementation()<cr>", "跳转到实现" }, -- 跳转到符号实现
    { "n", "<leader>gO", "<cmd>lua vim.lsp.buf.document_symbol()<cr>", "查看文档符号" }, -- 查看文档符号列表
    { "n", "<leader>grt", "<cmd>lua vim.lsp.buf.type_definition()<cr>", "跳转到类型定义" }, -- 跳转到类型定义
    { "n", "<leader>k", "<cmd>lua vim.lsp.buf.signature_help()<cr>", "显示函数签名帮助" }, -- 显示函数签名帮助
    { "n", "<leader>i", "<cmd>lua vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled())<cr>", "开启/关闭内联提示" }, -- 开启或关闭内联提示
  }

  -- 设置缓冲区的快捷键映射
  for _, map in ipairs(mappings) do
    -- 这些映射与缓冲区绑定，仅在 LSP 附加到缓冲区时设置
    vim.keymap.set(map[1], map[2], map[3], { noremap = true, silent = true, buffer = buf, desc = map[4] })
  end
end

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
  vim.lsp.handlers["textDocument/signatureHelp"] = vim.lsp.with(vim.lsp.handlers.signature_help, { border = "single" })
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
  setup_global_keymaps()     -- 设置全局按键映射

  -- 创建 LspAttach 自动命令
  vim.api.nvim_create_autocmd("LspAttach", {
    group = vim.api.nvim_create_augroup("UserLspConfig", { clear = false }),
    callback = function(args)
      local buf = args.buf
      setup_keymaps(buf)          -- 设置缓冲区特定的按键映射
      -- setup_highlight_symbol(buf) -- 高亮关键字
      setup_codelens_refresh(buf) -- 刷新 CodeLens
    end,
  })
end

return M
