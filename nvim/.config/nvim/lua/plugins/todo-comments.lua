-- https://github.com/folke/todo-comments.nvim

return {
	"folke/todo-comments.nvim",
	event = "BufReadPost",
	dependencies = { "nvim-lua/plenary.nvim" },
	config = function()
		require("todo-comments").setup()

		vim.keymap.set("n", "<leader>st", "<cmd>TodoQuickFix<cr>", { desc = "Next todo comment" })

		-- vim.keymap.set("n", "]t", function()
		-- 	require("todo-comments").jump_next()
		-- end, { desc = "Next todo comment" })
		--
		-- vim.keymap.set("n", "[t", function()
		-- 	require("todo-comments").jump_prev()
		-- end, { desc = "Previous todo comment" })
	end,
}
