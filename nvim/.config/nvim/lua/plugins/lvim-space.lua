-- https://github.com/lvim-tech/lvim-space
-- 项目 / 工作区 / 标签 / 文件 管理器（替代 resession.nvim 试用）
-- 依赖：sqlite.lua + lvim-utils + lvim-ui + lvim-picker（拉 lvim-fuzzy）
return {
	"lvim-tech/lvim-space",
	dependencies = {
		{ "kkharji/sqlite.lua" },
		{ "lvim-tech/lvim-utils" },
		{ "lvim-tech/lvim-ui" },
		{ "lvim-tech/lvim-fuzzy" },
		{ "lvim-tech/lvim-picker" },
	},
	config = function()
		require("lvim-space").setup({
			-- 默认是 "area"（会临时撑大 cmdheight）；本配置把 cmdheight 设为 0，
			-- 这里用居中浮窗，避免启动/打开面板时布局跳动。
			ui = { mode = "float" },
		})
	end,
}
