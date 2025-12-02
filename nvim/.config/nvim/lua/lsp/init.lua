-- lsp server 配置参考
-- https://github.com/neovim/nvim-lspconfig/tree/16666f1bc40f69ce05eb1883fd8c0d076284d8a5/lua/lspconfig/configs

local M = {}
local configs = require("lsp.config")
local autocmds = require("lsp.lsp_autocmds")

function M.setup()
	configs.lsp_Start() -- 启动lsp
	autocmds.setup() -- 配置初始化

	vim.api.nvim_create_user_command("LspListActive", function()
		local lsps = require("lsp.lsp_utils").get_active_lsps(0)
		if #lsps == 0 then
			print("No active LSP clients for this buffer.")
			return
		end
		print("Active LSPs:")
		for _, lsp in ipairs(lsps) do
			print(string.format("- %s (root: %s)", lsp.name, lsp.root_dir or "nil"))
		end
	end, { desc = "List active LSP clients for current buffer" })
end

return M
