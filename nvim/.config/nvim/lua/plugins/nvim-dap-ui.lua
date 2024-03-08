-- https://github.com/rcarriga/nvim-dap-ui

return {
	"rcarriga/nvim-dap-ui",
	dependencies = { "mfussenegger/nvim-dap" },
	keys = {
		{ "<leader>du", desc = "调试模式" },
	},
	config = function()
		require("dapui").setup()
		vim.keymap.set("n", "<leader>du", "<cmd>lua require'dapui'.toggle()<cr>")
	end,
}
