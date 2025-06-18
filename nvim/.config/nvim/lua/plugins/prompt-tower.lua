-- https://github.com/kylesnowschwartz/prompt-tower.nvim

return {
	"kylesnowschwartz/prompt-tower.nvim",
	keys = {
		{ "<leader>au", desc = "ai 文件选择器" },
		{ "<leader>ay", desc = "生成上下文" },
	},
	config = function()
		require("prompt-tower").setup({
			-- Configuration options (see below)
		})

		vim.keymap.set("n", "<leader>au", "<cmd>PromptTower<cr>", { desc = "ai 文件选择器" })
		vim.keymap.set("n", "<leader>ay", "<cmd>PromptTowerGenerate<cr>", { desc = "生成上下文" })
	end,
}
