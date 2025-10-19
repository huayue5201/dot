-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	event = "BufReadPost",
	config = function()
		local overseer = require("overseer")
		overseer.setup({
			dap = true,
			templates = { "builtin", "python" },
		})

		vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { silent = true, desc = "启动任务" })
		vim.keymap.set("n", "<leader>ol", "<cmd>OverseerToggle<cr>", { silent = true, desc = "任务列表" })
	end,
}
