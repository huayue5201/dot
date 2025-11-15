-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	event = "UIEnter",
	config = function()
		require("scope").setup({
			hooks = {
				pre_tab_enter = function()
					-- Your custom logic to run before entering a tab
				end,
			},
		})
	end,
}
