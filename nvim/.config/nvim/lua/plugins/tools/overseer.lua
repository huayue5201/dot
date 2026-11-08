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

		vim.keymap.set("n", "<leader>ru", "<cmd>OverseerRun<CR>", { desc = "Run task" })
		vim.keymap.set("n", "<leader>ro", "<cmd>OverseerToggle<CR>", { desc = "Open task list" })
	end,
}
