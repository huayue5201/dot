-- https://github.com/shellRaining/hlchunk.nvim/blob/main/README.zh-CN.md

return {
	"shellRaining/hlchunk.nvim",
	event = "UIEnter",
	config = function()
		require("hlchunk").setup({
			chunk = {
				enable = true,
			},
			indent = {
				enable = true,
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
