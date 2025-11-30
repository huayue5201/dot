-- https://github.com/linrongbin16/gentags.nvim

return {
	"linrongbin16/gentags.nvim",
	event = "VeryLazy",
	config = function()
		require("gentags").setup()
	end,
}
