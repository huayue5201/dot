-- https://github.com/hmdfrds/focal.nvim

return {
	"hmdfrds/focal.nvim",
	event = "VeryLazy",
	dependencies = {
		"3rd/image.nvim", -- optional if using chafa backend
	},
	config = function()
		require("focal").setup({
			-- Runtime toggle
			enabled = true,

			-- Window appearance
			border = "rounded", -- border style (any valid nvim_open_win border)
			winblend = 0, -- transparency (0-100)
			zindex = 100, -- float stacking order
			title = true, -- show filename in border

			-- Size constraints (in terminal cells)
			min_width = 10,
			min_height = 5,
			max_width = 80,
			max_height = 40,
			max_width_percent = 50, -- max width as % of editor
			max_height_percent = 50, -- max height as % of editor

			-- Performance
			max_file_size_mb = 5, -- skip files larger than this
			debounce_ms = 0, -- additional delay after CursorHold (0 = use updatetime)

			-- Position
			col_offset = 4, -- horizontal gap from cursor
			row_offset = 1, -- vertical gap from cursor

			-- Renderer override
			backend = nil, -- nil/"auto" = auto, "image.nvim", or "chafa"

			-- Extension whitelist (nil = all renderer-declared extensions)
			extensions = nil, -- e.g., { "png", "jpg" } to restrict

			-- Chafa-specific options
			chafa = {
				format = "symbols", -- chafa --format flag
				color_space = nil, -- nil = auto, "rgb", "din99d"
				animate = false, -- allow GIF animation
				max_output_bytes = 1048576, -- stdout cap (1MB)
			},

			-- Render timeout (ms). Auto-hides if render takes too long.
			render_timeout_ms = 10000,

			-- Lifecycle hooks
			on_show = nil, -- fun(path: string, renderer: string)
			on_hide = nil, -- fun()
		})
	end,
}
