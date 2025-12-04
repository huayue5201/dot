local M = {}

local icons = require("lsp.lsp_utils").icons.diagnostic
local lsp_get = require("lsp.lsp_utils")

M.diagnostic_config = function()
	vim.diagnostic.config({
		-- virtual_text = false, -- 设置false，诊断ui交给插件rachartier/tiny-inline-diagnostic.nvim
		virtual_text = {
			current_line = false,
		},
		virtual_lines = {
			current_line = true,
		},
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

-- 全局配置
M.global_config = function()
	vim.lsp.config("*", {
		capabilities = {
			textDocument = {
				semanticTokens = {
					multilineTokenSupport = true,
				},
			},
		},
		root_markers = { ".git" },
	})
end

-- 根据文件类型启动 LSP
local json_store = require("user.json_store")
M.lsp_Start = function()
	vim.api.nvim_create_autocmd("FileType", {
		desc = "根据文件类型启动或停止 LSP",
		pattern = lsp_get.get_lsp_config("filetypes"),
		callback = function()
			local lsp_name = lsp_get.get_lsp_name()
			if json_store.get_lsp_state(lsp_name[1]) == "inactive" then
				vim.lsp.enable(lsp_name, false)
			else
				vim.lsp.enable(lsp_name, true)
			end
		end,
	})
end

return M
