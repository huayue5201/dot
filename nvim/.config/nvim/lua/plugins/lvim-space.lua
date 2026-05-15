-- https://github.com/lvim-tech/lvim-space

return {
	"lvim-tech/lvim-space",
	dependencies = {
		"kkharji/sqlite.lua",
		"lvim-tech/lvim-utils",
	},
	config = function()
		require("lvim-space").setup({})
	end,
}
