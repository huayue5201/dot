-- https://github.com/shellRaining/hlchunk.nvim/blob/main/README.zh-CN.md

return {
	"shellRaining/hlchunk.nvim",
	event = { "UIEnter" },
	config = function()
		require("hlchunk").setup({})
	end,
}
