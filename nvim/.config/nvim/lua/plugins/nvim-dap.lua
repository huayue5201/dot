-- https://github.com/mfussenegger/nvim-dap
-- https://github.com/igorlfs/nvim-dap-view

return {
	"mfussenegger/nvim-dap",
	lazy = true,
	dependencies = {
		{ "igorlfs/nvim-dap-view", opts = {} },
	},
	config = function()
		vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
	end,
}
