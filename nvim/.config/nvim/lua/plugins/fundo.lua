-- https://github.com/kevinhwang91/nvim-fundo

return {
	"kevinhwang91/nvim-fundo",
	dependencies = "kevinhwang91/promise-async",
	build = function()
		require("fundo").install()
	end,
	event = "BufReadPost",
	config = function()
		vim.o.undofile = true
		require("fundo").setup()
	end,
}
