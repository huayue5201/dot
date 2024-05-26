-- https://github.com/shellRaining/hlchunk.nvim/blob/main/README.zh-CN.md

return {
	"shellRaining/hlchunk.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("hlchunk").setup({
			default_conf = {
				enable = false,
				style = {},
				notify = false,
				priority = 0,
				exclude_filetypes = {
					aerial = true,
					dashboard = true,
					-- some other filetypes
				},
			},
			chunk = {
				enable = true,
				-- ...
			},
			indent = {
				enable = true,
				-- ...
			},
			line_num = {
				enable = true,
			},
			blank = {
				enable = true,
			},
		})
	end,
}
