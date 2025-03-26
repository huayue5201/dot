-- https://github.com/neovim/neovim/releases/
-- https://neovim.io/

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置配色方案
-- vim.cmd("colorscheme ansi")

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 加载配置文件
require("config.settings")
require("config.lazy")
require("config.autocmds")
require("config.usercmds")
require("config.statusline")
require("config.keymaps")

-- lsp 全局配置
vim.lsp.config("*", {
	root_markers = { ".git" },
	capabilities = {
		textDocument = {
			semanticTokens = {
				multilineTokenSupport = true,
			},
		},
	},
})
-- 启用 LSP 服务器
vim.lsp.enable({ "lua_ls", "clangd", "taplo", "rust-analyzer" })

-- 添加 fzf 到 runtimepath
vim.opt.runtimepath:append("/opt/homebrew/opt/fzf")
