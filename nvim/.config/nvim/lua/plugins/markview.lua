---@diagnostic disable: missing-fields
-- https://github.com/OXY2DEV/markview.nvim
-- For `plugins/markview.lua` users.
return {
	"OXY2DEV/markview.nvim",
	-- Completion for `blink.cmp`
	dependencies = { "saghen/blink.cmp" },
	lazy = false,
	ft = "md",
	config = function()
		require("markview").setup({
			markdown = {
				list_items = {
					indent = true,
					indent_size = 2, -- 固定缩进2个空格
					-- 或者使用 shiftwidth
					-- indent_size = vim.bo.shiftwidth,

					-- 也可以配置不同标记的样式
					marker_minus = {
						add_padding = false, -- 总是添加内边距
						-- 或者 false 从不添加
					},
					marker_plus = {
						add_padding = true,
					},
					marker_star = {
						add_padding = true,
					},
				},
			},
			markdown_inline = {
				enable = true, -- 确保内联元素启用

				checkboxes = {
					enable = false, -- 禁用复选框渲染
					-- 其他可能的配置项：
					-- hl_unchecked = "MarkviewCheckboxUnchecked",
					-- hl_checked = "MarkviewCheckboxChecked",
					-- icon_unchecked = "󰄱",
					-- icon_checked = "󰄲",
				},

				-- 其他内联元素的配置...
			},
		})
	end,
}
