-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	config = function()
		require("overseer").setup({
			task_list = {
				-- Default direction. Can be "left", "right", or "bottom"
				direction = "left",
			},
		})

		vim.keymap.set("n", "<leader>ru", "<cmd>OverseerRun<CR>", { desc = "运行任务" })
		vim.keymap.set("n", "<leader>rt", "<cmd>OverseerToggle<CR>", { desc = "打开任务列表" })
	end,
}
