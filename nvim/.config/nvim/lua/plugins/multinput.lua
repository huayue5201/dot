-- https://github.com/r0nsha/multinput.nvim

return {
	"r0nsha/multinput.nvim",
	event = "VeryLazy",
	config = function()
		require("multinput").setup({
			-- Your custom configuration goes here
		})
	end,
}
