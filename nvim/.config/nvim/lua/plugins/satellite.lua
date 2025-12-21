-- https://github.com/lewis6991/satellite.nvim

return {
	"lewis6991/satellite.nvim",
	event = "VeryLazy",
	config = function()
		require("satellite").setup()
	end,
}
