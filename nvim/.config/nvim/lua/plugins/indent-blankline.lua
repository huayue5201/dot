-- https://github.com/lukas-reineke/indent-blankline.nvim
-- 缩进线

return {
	"lukas-reineke/indent-blankline.nvim",
	event = { "BufReadPost", "BufNewFile" },
	opts = {
		char = "│",
		show_end_of_line = true,
		space_char_blankline = "▫",
		show_trailing_blankline_indent = true,
		show_current_context = true,
		show_current_context_start = true,
	},
}
