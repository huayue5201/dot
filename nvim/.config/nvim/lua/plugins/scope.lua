-- https://github.com/tiagovla/scope.nvim

return {
	"tiagovla/scope.nvim",
	event = "UIEnter",
	config = function()
		require("scope").setup({
			-- [other options]
		})
	end,
}
