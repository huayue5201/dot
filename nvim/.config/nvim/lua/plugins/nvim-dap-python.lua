-- https://codeberg.org/mfussenegger/nvim-dap-python

return {
	"mfussenegger/nvim-dap-python",
	ft = "python",
	config = function()
		require("dap-python").setup("uv")
	end,
}
