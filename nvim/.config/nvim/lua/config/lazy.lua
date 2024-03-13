-- https://github.com/folke/lazy.nvim
-- 安装lazy

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
	vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git",
		"--branch=stable", -- latest stable release
		lazypath,
	})
end
vim.opt.rtp:prepend(lazypath)

-- lazy配置

require("lazy").setup({
	spec = {
		{ import = "plugins" },
	},
	defaults = { lazy = true, version = false }, -- always use the latest git commit
})
