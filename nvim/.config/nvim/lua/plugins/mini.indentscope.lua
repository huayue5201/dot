-- https://github.com/nvim-mini/mini.indentscope

return {
	"nvim-mini/mini.indentscope",
	version = "*",
	event = "VeryLazy",
	config = function()
		require("mini.indentscope").setup()
	end,
}
