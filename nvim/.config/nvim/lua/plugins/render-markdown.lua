-- https://github.com/MeanderingProgrammer/render-markdown.nvim

return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	ft = { "markdown", "Avante" },
	config = function()
		require("render-markdown").setup({
			file_types = { "markdown", "Avante" },
		})
	end,
}
