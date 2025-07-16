-- https://github.com/kylesnowschwartz/prompt-tower.nvim

return {
	"kylesnowschwartz/prompt-tower.nvim",
	keys = { "<leader>ap" },
	config = function()
		require("prompt-tower").setup({
			-- Configuration options (see below)
		})

		vim.keymap.set("n", "<leader>ap", "<cmd>PromptTower<cr>", { desc = "ai 上下文" })
	end,
}
