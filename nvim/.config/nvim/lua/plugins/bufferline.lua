-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("bufferline").setup({
			options = {
				hover = {
					enabled = true,
					delay = 50,
					reveal = { "close" },
				},
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						highlight = "Directory",
						text_align = "center",
					},
					{
						filetype = "aerial",
						text = "Symbol Tree",
						highlight = "Directory",
						text_align = "center",
					},
				},
			},
		})
	end,
}
