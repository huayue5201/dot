-- https://github.com/OXY2DEV/markview.nvim
-- For `plugins/markview.lua` users.
return {
	"OXY2DEV/markview.nvim",
	lazy = false,
	ft = "md",

	-- Completion for `blink.cmp`
	dependencies = { "saghen/blink.cmp" },
}
