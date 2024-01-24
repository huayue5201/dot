-- https://github.com/williamboman/mason.nvim

return {
	"williamboman/mason.nvim",
	event = "VeryLazy",
	config = function()
		require("mason").setup({})
	end,
}
