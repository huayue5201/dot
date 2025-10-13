-- https://github.com/kevinhwang91/nvim-fundo

return {
	"kevinhwang91/nvim-fundo",
	event = "BufReadPost",
	dependencies = "kevinhwang91/promise-async",
	build = function()
		require("fundo").install()
	end,
	config = function()
		vim.o.undofile = true
		require("fundo").setup()
	end,
}
