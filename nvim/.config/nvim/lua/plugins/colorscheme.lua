-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/uhs-robert/oasis.nvim

return {
	-- "oxfist/night-owl.nvim",
	"EdenEast/nightfox.nvim",
	-- "uhs-robert/oasis.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")

		require("nightfox").setup({
			options = {
				-- 是否使非焦点窗口使用不同的背景颜色，增强视觉分隔
				dim_inactive = true,
			},
		})
		vim.cmd("colorscheme Carbonfox")

		-- require("oasis").setup({
		-- 	dark_style = "lagoon", -- 当 vim.o.background 为 "dark" 时使用的主题样式
		-- 	light_style = "dawn", -- 当 vim.o.background 为 "light" 时使用的主题样式
		-- 	style = nil, -- 可选：强制使用单一主题（如 "lagoon", "desert"），禁用自动切换
		-- 	use_legacy_comments = false, -- 是否使用 desert.vim 旧版注释颜色（仅对 "desert" 样式生效，亮天蓝色）
		--
		-- 	-- 文本样式设置 - 可以单独关闭某些效果
		-- 	styles = {
		-- 		bold = true, -- 是否启用粗体（关键字、函数等）
		-- 		italic = true, -- 是否启用斜体（注释、部分关键字）
		-- 		underline = true, -- 是否启用下划线（匹配单词等）
		-- 		undercurl = true, -- 是否启用波浪线（诊断、拼写错误提示）
		-- 		strikethrough = true, -- 是否启用删除线（废弃内容）
		-- 	},
		--
		-- 	-- 显示选项
		-- 	transparent = false, -- 启用透明背景（去掉主题的背景色）
		-- 	terminal_colors = true, -- 将 Oasis 的配色应用到 Neovim 内置终端
		--
		-- 	palette_overrides = {}, -- 覆盖调色板中的特定颜色
		-- 	highlight_overrides = {}, -- 覆盖特定 highlight 组的颜色
		-- })

		-- vim.cmd.colorscheme("oasis") -- After setup, apply theme (or a any style like "oasis-night")
	end,
}
