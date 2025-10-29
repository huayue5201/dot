-- https://github.com/oxfist/night-owl.nvim
-- https://github.com/EdenEast/nightfox.nvim
-- https://github.com/folke/tokyonight.nvim

return {
	-- "oxfist/night-owl.nvim",
	-- "EdenEast/nightfox.nvim",
	-- "folke/tokyonight.nvim",
	"Mofiqul/vscode.nvim",
	lazy = false,
	priority = 1000,
	config = function()
		-- require("night-owl").setup()
		-- vim.cmd.colorscheme("night-owl")
		-- vim.cmd("colorscheme Carbonfox")

		local c = require("vscode.colors").get_colors()
		require("vscode").setup({
			-- 也可以在这里直接设置主题风格
			style = "dark",

			-- 启用透明背景
			transparent = false,

			-- 启用注释斜体
			italic_comments = true,

			-- 启用 Inlay Hints 的斜体
			italic_inlayhints = true,

			-- 为 `@markup.link.*` 类型添加下划线
			underline_links = true,

			-- 禁用 nvim-tree 的背景颜色
			disable_nvimtree_bg = true,

			-- 将主题颜色应用到终端
			terminal_colors = true,

			-- 自定义颜色（参见 ./lua/vscode/colors.lua）
			color_overrides = {
				vscLineNumber = "#FFFFFF",
			},

			-- 自定义高亮组（参见 ./lua/vscode/theme.lua）
			group_overrides = {
				-- 该配置与 vim.api.nvim_set_hl 的参数结构相同
				-- 可通过 require('vscode.colors') 使用主题颜色
				Cursor = { fg = c.vscDarkBlue, bg = c.vscLightGreen, bold = true },
			},
		})
		-- require('vscode').load()

		-- 加载主题，但不影响 devicon 的颜色
		vim.cmd.colorscheme("vscode")
		-- vim.cmd([[colorscheme tokyonight-night]])
	end,
}
