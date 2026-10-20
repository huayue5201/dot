-- 基本缩进（必须用 opt_local：vim.o/vim.opt 会连全局值一起改，泄漏到其它 buffer，
-- 也会盖掉 guess-indent 的检测结果）
vim.opt_local.tabstop = 2
vim.opt_local.shiftwidth = 2
vim.opt_local.expandtab = true

vim.g.lsp_inline_completion_enabled = false

-- conceal 设置
-- vim.opt.conceallevel = 2
-- vim.opt.concealcursor = "nc"
