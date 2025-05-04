vim.opt.expandtab = false
-- 消除换行符
vim.api.nvim_create_autocmd("BufWritePre", {
	pattern = "*",
	command = "%s/\r//g",
})
