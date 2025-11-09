-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}
local configs = require("lsp.config")
local autocmds = require("lsp.autocmds")

function M.setup()
	configs.lsp_Start() -- 启动lsp
	autocmds.setup() -- 配置初始化
end

return M
