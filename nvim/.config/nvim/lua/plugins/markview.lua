-- https://github.com/OXY2DEV/markview.nvim

-- For `plugins/markview.lua` users.
return {
	"OXY2DEV/markview.nvim",
	ft = { "markdown", "html", "latex", "typst", "yaml" },
	dependencies = "nvim-tree/nvim-web-devicons",

	-- For blink.cmp's completion
	-- source
	-- dependencies = {
	--     "saghen/blink.cmp"
	-- },
}
