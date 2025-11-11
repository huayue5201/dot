-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-jump.md

return {
	"nvim-mini/mini.jump",
	event = "BufReadPost",
	config = function()
		require("mini.jump").setup()
	end,
}
