-- https://github.com/stevearc/overseer.nvim

return {
	"stevearc/overseer.nvim",
	ft = { "c", "rust", "lua" },
	config = function()
		local overseer = require("overseer")
		overseer.setup({
			templates = { "builtin", "user" }, -- 添加自定义模板
		})

		vim.keymap.set("n", "<leader>or", "<cmd>OverseerRun<cr>", { desc = "Run overseer" })
		vim.keymap.set("n", "<leader>ot", "<cmd>OverseerToggle<cr>", { desc = "Overseer任务列表" })
	end,
}
