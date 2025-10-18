-- https://codeberg.org/mfussenegger/nvim-dap-python

return {
	"mfussenegger/nvim-dap-python",
	event = "VeryLazy",
	config = function()
		require("dap-python").setup("uv")
	end,
}
