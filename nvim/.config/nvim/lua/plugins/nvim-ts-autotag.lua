-- https://github.com/windwp/nvim-ts-autotag

return {
	"windwp/nvim-ts-autotag",
	ft = { "html" },
	config = function()
		require("nvim-ts-autotag").setup()
	end,
}
