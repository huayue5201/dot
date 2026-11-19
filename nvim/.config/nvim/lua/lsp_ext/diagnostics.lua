-- lua/lsp_ext/diagnostics.lua
---@brief 诊断 UI 配置（图标 / 虚拟文本 / 浮动窗 / 下划线 / 排序）
---@diagnostic disable: assign-type-mismatch, missing-fields
local icons = require("lsp_ext.icons")
local M = {}

function M.setup()
	vim.diagnostic.config({
		-- 行内提示交给 tiny-inline-diagnostic.nvim（见 lua/plugins/lsp/tiny-inline-diagnostic.lua）
		-- 必须关闭内置的 virtual_text / virtual_lines，否则会与插件重复渲染
		virtual_text = false,
		virtual_lines = false,
		-- 浮动窗口（:lua vim.diagnostic.open_float() / <leader>e 等触发）
		float = {
			border = "rounded", -- 圆角边框，配色跟随当前主题
			source = "always", -- 显示来源（LSP 名称）
			header = "", -- 不显示标题栏
			prefix = "", -- 消息前缀留空（默认是 "● "）
			focusable = false, -- 窗口不可聚焦，避免抢走光标
		},
		-- 行号左侧的符号与高亮
		signs = {
			text = { -- 每个严重级别对应的图标
				[vim.diagnostic.severity.ERROR] = icons.ERROR,
				[vim.diagnostic.severity.WARN] = icons.WARN,
				[vim.diagnostic.severity.HINT] = icons.HINT,
				[vim.diagnostic.severity.INFO] = icons.INFO,
			},
			numhl = { -- 按严重级别给行号上高亮色
				[vim.diagnostic.severity.ERROR] = "ErrorMsg",
				[vim.diagnostic.severity.WARN] = "WarningMsg",
			},
		},
		underline = true, -- 用下划线标出问题代码段
		update_in_insert = true, -- 插入模式下也实时刷新诊断
		severity_sort = true, -- 同一行/同一窗口内按严重级别排序（错误优先）
	})
	vim.lsp.log.set_level(4) -- 日志等级：4=WARN 及以上，只记录警告/错误，避免日志膨胀
end

return M
