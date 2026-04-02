---@diagnostic disable: assign-type-mismatch, missing-fields
local M = {}

M.icons = {
	ERROR = " ",
	WARN = " ",
	HINT = " ",
	INFO = "󰙎",
}

M.diagnostic_config = function()
	vim.diagnostic.config({
		-- 虚拟文本（行内提示）
		virtual_text = {
			-- prefix = "●", -- 更专业的符号，不会乱跳
			spacing = 2,
			current_line = false,
			-- severity = { min = vim.diagnostic.severity.WARN },
		},
		virtual_lines = {
			current_line = true,
		},
		-- 浮动窗口
		float = {
			border = "rounded",
			source = "always", -- 显示来源（LSP 名称）
			header = "",
			prefix = "",
			focusable = false,
		},
		signs = {
			text = {
				[vim.diagnostic.severity.ERROR] = M.icons.ERROR,
				[vim.diagnostic.severity.WARN] = M.icons.WARN,
				[vim.diagnostic.severity.HINT] = M.icons.HINT,
				[vim.diagnostic.severity.INFO] = M.icons.INFO,
			},
			numhl = {
				[vim.diagnostic.severity.ERROR] = "ErrorMsg",
				[vim.diagnostic.severity.WARN] = "WarningMsg",
			},
		},
		-- 下划线
		underline = true,
		update_in_insert = true,
		-- 排序（更重要的诊断优先）
		severity_sort = true,
	})
	vim.lsp.log.set_level(4) -- 日志等级,只记录错误输出
	-- 自动打开诊断浮窗
	-- vim.cmd([[autocmd CursorMoved * lua vim.diagnostic.open_float(nil, {focusable = false})]])
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
