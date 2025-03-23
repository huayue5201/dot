-- https://github.com/williamboman/mason.nvim

return {
	"williamboman/mason.nvim",
	ft = { "lua", "tmol", "rust", "c" },
	cmd = "Mason",
	config = function()
		require("mason").setup({
			ui = {
				border = "rounded",
			},
		})
	end,
}
