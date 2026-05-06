-- https://github.com/chrisgrieser/nvim-scissors

return {
	"chrisgrieser/nvim-scissors",
	config = function()
		require("scissors").setup({
			snippetDir = vim.fn.stdpath("config") .. "/snippets",
		})

		vim.keymap.set("n", "<leader>se", function()
			require("scissors").editSnippet()
		end, { desc = "Snippet: Edit" })

		vim.keymap.set(
			{ "n", "x" }, -- when used in visual mode, prefills the selection as snippet body
			"<leader>sa",
			function()
				require("scissors").addNewSnippet()
			end,
			{ desc = "Snippet: Add" }
		)
	end,
}
