---@diagnostic disable: assign-type-mismatch, missing-fields
local M = {}

local icons = {
	ERROR = "",
	WARN = "",
	HINT = "",
	INFO = "",
}

M.diagnostic_config = function()
	vim.diagnostic.config({
		severity_sort = true,
		float = {
			source = "if_many",
			border = "solid",
		},
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = icons.ERROR,
				[vim.diagnostic.severity.WARN] = icons.WARN,
				[vim.diagnostic.severity.HINT] = icons.HINT,
				[vim.diagnostic.severity.INFO] = icons.INFO,
			},
			numhl = {
				[vim.diagnostic.severity.ERROR] = "ErrorMsg",
				[vim.diagnostic.severity.WARN] = "WarningMsg",
			},
		},
		underline = true,
		update_in_insert = true,
	})
	vim.lsp.log.set_level(4) -- 日志等级,只记录错误输出
end

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

local lsp_get = require("lsp-config.lsp_utils")
local Store = require("nvim-store3").project()

M.lsp_Start = function()
	vim.api.nvim_create_autocmd("FileType", {
		desc = "根据文件类型启动或停止 LSP",
		pattern = lsp_get.get_lsp_config("filetypes"),
		callback = function()
			local lsp_names = lsp_get.get_lsp_by_filetype(vim.bo.filetype)

			for _, lsp_name in ipairs(lsp_names) do
				local state = Store:get("lsp." .. lsp_name)

				if state == "inactive" then
					vim.lsp.enable(lsp_name, false)
				else
					vim.lsp.enable(lsp_name, true)
				end
			end
		end,
	})
end

return M
