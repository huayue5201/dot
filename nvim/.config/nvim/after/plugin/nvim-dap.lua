-- https://github.com/mfussenegger/nvim-dap

vim.g.later(function()
	vim.g.add({ source = "mfussenegger/nvim-dap" })

	vim.fn.sign_define("DapBreakpoint", { text = "🔴", texthl = "", linehl = "", numhl = "" })
end)
