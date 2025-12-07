-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}
local configs = require("lsp-config.setings")
local autocmds = require("lsp-config.lsp_autocmds")
local keymap = require("lsp-config.lsp_keymaps")

function M.setup()
	configs.lsp_Start() -- 启动lsp
	configs.global_config() -- 全局配置
	autocmds.setup() -- 配置初始化
	keymap.global_keymaps() -- 全局按键映射
end

return M
