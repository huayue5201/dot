-- 光标自动定位到最后编辑的位置
vim.api.nvim_create_autocmd("BufReadPost", {
   command = [[if line("'\"") > 1 && line("'\"") <= line("$") | execute "normal! g`\"" | endif]],
})

vim.api.nvim_create_autocmd("BufEnter", { command = [[set formatoptions-=cro]] })

-- 用q关闭窗口
vim.api.nvim_create_autocmd("FileType", {
   pattern = { "help", "startuptime", "qf", "lspinfo" },
   command = [[nnoremap <buffer><silent> q :close<CR>]],
})
vim.api.nvim_create_autocmd("FileType", {
   pattern = "man",
   command = [[nnoremap <buffer><silent> q :quit<CR>]],
})

-- 仅在活动窗口显示光标线
local cursorGrp = vim.api.nvim_create_augroup("CursorLine", { clear = true })
vim.api.nvim_create_autocmd({ "InsertLeave", "WinEnter" }, {
   pattern = "*",
   command = "set cursorline",
   group = cursorGrp,
})
vim.api.nvim_create_autocmd(
   { "InsertEnter", "WinLeave" },
   { pattern = "*", command = "set nocursorline", group = cursorGrp }
)

--- 保存时删除所有尾随空格
local TrimWhiteSpaceGrp = vim.api.nvim_create_augroup("TrimWhiteSpaceGrp", { clear = true })
vim.api.nvim_create_autocmd("BufWritePre", {
   command = [[:%s/\s\+$//e]],
   group = TrimWhiteSpaceGrp,
})

--================
-- 创建高亮组并添加 TextYankPost 自动命令
local highlight_group = vim.api.nvim_create_augroup("YankHighlight", { clear = true })
-- 添加 TextYankPost 自动命令
vim.api.nvim_create_autocmd("TextYankPost", {
   callback = function()
      vim.highlight.on_yank()
   end,
   group = highlight_group,
   pattern = "*",
})

--================
-- Toggle hlsearch based on specific keys in Normal mode
if vim.g.enabled_toggle_hlsearch then
   return
end
vim.g.enabled_toggle_hlsearch = true
local function toggle_hlsearch(char)
   -- Check if in Normal mode
   if vim.fn.mode() == "n" then
      local toggle_keys = { "<CR>", "n", "N", "*", "#", "?", "/" }
      local should_toggle = vim.tbl_contains(toggle_keys, vim.fn.keytrans(char))
      -- Toggle hlsearch if needed
      if vim.opt.hlsearch:get() ~= should_toggle then
         vim.opt.hlsearch = should_toggle
      end
   end
end
-- Register the key handler for toggling hlsearch
vim.on_key(toggle_hlsearch, vim.api.nvim_create_namespace("toggle_hlsearch"))
