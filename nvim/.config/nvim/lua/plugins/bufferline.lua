-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	tag = "*",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("bufferline").setup({
			options = {
				themable = true,
				close_icon = "",
				custom_areas = {
					right = require("visual_studio_code").get_bufferline_right(),
				},
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
