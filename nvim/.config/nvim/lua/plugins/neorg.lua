-- https://github.com/nvim-neorg/neorg

return {
	"nvim-neorg/neorg",
	build = ":Neorg sync-parsers",
	dependencies = "nvim-lua/plenary.nvim",
	ft = "norg",
	opts = {
		load = {
			-- 基础模块
			["core.defaults"] = {},
			-- 把标记符渲染成图标
			["core.concealer"] = {},
			-- neorg workspaces管理
			["core.dirman"] = {
				config = {
					workspaces = {
						notes = "~/notes",
					},
				},
			},
		},
	},
}
