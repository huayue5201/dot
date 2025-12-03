-- https://github.com/mrjones2014/smart-splits.nvim

return {
	"mrjones2014/smart-splits.nvim",
	event = "WinNew",
	config = function()
		---@diagnostic disable: missing-fields
		require("smart-splits").setup({})
		-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
		vim.keymap.set("n", "<A-Left>", require("smart-splits").resize_left, { desc = "Resize split left" })
		vim.keymap.set("n", "<A-Down>", require("smart-splits").resize_down, { desc = "Resize split down" })
		vim.keymap.set("n", "<A-Up>", require("smart-splits").resize_up, { desc = "Resize split up" })
		vim.keymap.set("n", "<A-Right>", require("smart-splits").resize_right, { desc = "Resize split right" })

		-- moving between splits
		vim.keymap.set("n", "<s-a-Left>", require("smart-splits").move_cursor_left, { desc = "Move cursor left" })
		vim.keymap.set("n", "<s-a-Down>", require("smart-splits").move_cursor_down, { desc = "Move cursor down" })
		vim.keymap.set("n", "<s-a-Up>", require("smart-splits").move_cursor_up, { desc = "Move cursor up" })
		vim.keymap.set("n", "<s-a-Right>", require("smart-splits").move_cursor_right, { desc = "Move cursor right" })
		vim.keymap.set(
			"n",
			"<C-[>",
			require("smart-splits").move_cursor_previous,
			{ desc = "Move cursor to previous split" }
		)

		-- swapping buffers between windows
		vim.keymap.set(
			"n",
			"<leader><leader>h",
			require("smart-splits").swap_buf_left,
			{ desc = "Swap buffer to the left" }
		)
		vim.keymap.set("n", "<leader><leader>j", require("smart-splits").swap_buf_down, { desc = "Swap buffer down" })
		vim.keymap.set("n", "<leader><leader>k", require("smart-splits").swap_buf_up, { desc = "Swap buffer up" })
		vim.keymap.set(
			"n",
			"<leader><leader>l",
			require("smart-splits").swap_buf_right,
			{ desc = "Swap buffer to the right" }
		)
	end,
}
