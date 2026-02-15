return {
	dir = "~/todo2",
	event = "VeryLazy", -- 延迟加载，保证启动速度
	dependencies = { "nvim-store3" },
	name = "todo2",
	config = function()
		require("todo2").setup({
			ui = {
				conceal = {
					enable = true,
				},
			},
		})
	end,
}
