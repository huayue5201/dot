-- https://github.com/nvim-mini/mini.jump2d

return {
	"nvim-mini/mini.jump2d",
	event = "VeryLazy", -- 延迟加载（在 VeryLazy 事件触发时加载）
	version = "*",
	config = function()
		require("mini.jump2d").setup({
			view = {
				-- Whether to dim lines with at least one jump spot
				dim = false,

				-- How many steps ahead to show. Set to big number to show all steps.
				n_steps_ahead = 0,
			},
			mappings = {
				start_jumping = "s",
			},
		})
	end,
}
