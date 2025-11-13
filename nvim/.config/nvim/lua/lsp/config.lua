local M = {}

local icons = require("lsp.utils").icons.diagnostic
local lsp_get = require("lsp.utils")

M.diagnostic_config = function()
	vim.diagnostic.config({
		virtual_text = false, -- 设置false，诊断ui交给插件rachartier/tiny-inline-diagnostic.nvim
		-- virtual_text = {
		-- 	current_line = false,
		-- },
		-- virtual_lines = {
		-- 	current_line = true,
		-- },
		severity_sort = true,
		-- float = { source = "if_many", border = "shadow" },
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = icons.ERROR,
				[vim.diagnostic.severity.WARN] = icons.WARN,
				[vim.diagnostic.severity.HINT] = icons.HINT,
				[vim.diagnostic.severity.INFO] = icons.INFO,
			},
			linehl = { [vim.diagnostic.severity.ERROR] = "ErrorMsg" },
			numhl = { [vim.diagnostic.severity.WARN] = "WarningMsg" },
		},
		underline = true,
		update_in_insert = true,
	})
end

-- 根据文件类型启动 LSP
M.lsp_Start = function()
	vim.api.nvim_create_autocmd("FileType", {
		desc = "根据文件类型启动或停止 LSP",
		pattern = lsp_get.get_lsp_config("filetypes"),
		callback = function()
			vim.lsp.enable(lsp_get.get_lsp_name(), true)
			-- vim.lsp.stop_client(lsp_get.get_lsp_name())
		end,
	})
end

return M
