-- https://github.com/kevinhwang91/nvim-fundo

return {
	"kevinhwang91/nvim-fundo",
	event = "BufReadPost",
	dependencies = {
		"kevinhwang91/promise-async",
		build = function()
			require("fundo").install()
		end,
	},
	init = function()
		vim.o.undofile = true
	end,
	config = function()
		require("fundo").setup()
	end,
}
