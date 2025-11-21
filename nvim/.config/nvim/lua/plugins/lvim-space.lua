-- https://github.com/lvim-tech/lvim-space

return {
	"lvim-tech/lvim-space",
	event = "VeryLazy",
	dependencies = { "kkharji/sqlite.lua" },
	config = function()
		require("lvim-space").setup({
			autosave = true, -- 自动保存 workspace 状态

			ui = {
				icons = {
					project = "", -- 项目 icon，可以换成你喜欢的 Nerd Font 图标
					workspace = "",
					tab = "",
					file = "",
				},
				-- 你也可以设置浮动窗口样式、边框等 UI 选项（视插件支持）
				float = {
					border = "rounded",
					width = 0.8,
					height = 0.8,
				},
			},

			keymappings = {
				main = "<C-Space>", -- 打开主面板
				global = {
					projects = "p",
					workspaces = "w",
					tabs = "t",
					files = "f",
				},
			},

			-- 其他配置 (如果插件支持的话)
			-- 比如：数据库路径、自动恢复等等
			db_path = vim.fn.stdpath("data") .. "/lvim-space.sqlite",
		})

		-- （可选）状态栏集成示例（假设你用 lualine /其它 statusline）
		local pub = require("lvim-space.pub")
		-- pub.get_tab_info() 可以拿到当前 workspace/tab 列表信息
		-- 然后你可以把这些信息显示在状态栏里
	end,
}
