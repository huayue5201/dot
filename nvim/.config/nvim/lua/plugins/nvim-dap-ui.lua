-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	dependencies = {
		"mfussenegger/nvim-dap",
		"nvim-neotest/nvim-nio",
	},
	keys = {
		{ "<leader>du", desc = "调试模式" },
	},
	config = function()
		require("dapui").setup()
		keymap("n", "<leader>du", "<cmd>lua require'dapui'.toggle()<cr>")
	end,
}
