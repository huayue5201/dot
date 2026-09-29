-- lua/lsp-config/diagnostics.lua
---@brief 诊断 UI 配置（图标 / 虚拟文本 / 浮动窗 / 下划线 / 排序）
---@diagnostic disable: assign-type-mismatch, missing-fields
local icons = require("lsp-config.icons")
local M = {}

function M.setup()
	vim.diagnostic.config({
		-- 虚拟文本（行内提示）
		virtual_text = {
			spacing = 2,
			current_line = false,
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
		severity_sort = true,
	})
	vim.lsp.log.set_level(4) -- 日志等级，只记录错误输出
end

return M
