-- https://github.com/kevinhwang91/nvim-fundo

return {
	"kevinhwang91/nvim-fundo",
	requires = "kevinhwang91/promise-async",
	event = { "BufReadPre" },
	run = function()
		require("fundo").install()
	end,
	config = function()
		vim.o.undofile = true
		require("fundo").setup()
	end,
}
