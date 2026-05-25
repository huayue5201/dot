-- https://github.com/olimorris/codecompanion.nvim

return {
	"olimorris/codecompanion.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-treesitter/nvim-treesitter",
	},
	config = function()
		-- Other package managers
		require("codecompanion").setup({
			interactions = {
				chat = {
					adapter = "copilot",
				},
			},
		})

		-- 以 <Leader>a 为前缀的映射
		vim.keymap.set(
			{ "n", "v" },
			"<A-a>",
			"<cmd>CodeCompanionActions<cr>",
			{ noremap = true, silent = true, desc = "Open actions palette" }
		)

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>aa",
			"<cmd>CodeCompanionChat Toggle<cr>",
			{ noremap = true, silent = true, desc = "Toggle chat buffer" }
		)

		vim.keymap.set(
			"v",
			"<Leader>as",
			"<cmd>CodeCompanionChat Add<cr>",
			{ noremap = true, silent = true, desc = "Add selection to chat" }
		)

		vim.keymap.set(
			{ "n", "v" },
			"<Leader>ai",
			"<cmd>CodeCompanion<cr>",
			{ noremap = true, silent = true, desc = "Inline interaction" }
		)

		vim.keymap.set(
			"n",
			"<Leader>al",
			"<cmd>CodeCompanionCLI<cr>",
			{ noremap = true, silent = true, desc = "Open CLI interaction" }
		)

		vim.keymap.set(
			"n",
			"<Leader>am",
			"<cmd>CodeCompanionCmd<cr>",
			{ noremap = true, silent = true, desc = "Generate command" }
		)

		-- 命令行缩写
		vim.cmd([[cab cc CodeCompanion]])
	end,
}
