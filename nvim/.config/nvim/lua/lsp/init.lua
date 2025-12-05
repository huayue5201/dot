-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}
local configs = require("lsp.config")
local autocmds = require("lsp.lsp_autocmds")
local keymap = require("lsp.lsp_keymaps")

function M.setup()
	configs.lsp_Start() -- 启动lsp
	configs.global_config() -- 全局配置
	autocmds.setup() -- 配置初始化

	vim.keymap.set("n", "<leader>rl", function()
		keymap.restart_lsp()
	end, { noremap = true, silent = true, desc = "LSP: 重启lsp" })

	vim.keymap.set("n", "<leader>lt", function()
		keymap.toggle_lsp()
	end, { desc = "Toggle LSP for current filetype" })

	vim.keymap.set("n", "<leader>yd", function()
		keymap.CopyErrorMessage()
	end, { noremap = true, silent = true, desc = "LSP: 复制lsp诊断" })
end

return M
