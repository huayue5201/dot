-- https://github.com/ibhagwan/fzf-lua

return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	-- dependencies = { "nvim-mini/mini.icons" },
	opts = {},
	config = function()
		require("fzf-lua").setup({
			keymap = {
				fzf = {
					true,
					-- Use <c-q> to select all items and add them to the quickfix list
					["ctrl-q"] = "select-all+accept",
				},
			},
		})
		vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "fzf: files" })
		vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "fzf: buffer" })
		vim.keymap.set("n", "<leader>fo", "<cmd>FzfLua oldfiles<cr>", { desc = "fzf: oldfiles" })
		vim.keymap.set("n", "<leader>fr", function()
			require("fzf-lua").grep({ resume = true })
		end, { desc = "fzf: grep" })
		vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua btags<cr>", { desc = "fzf: btags" })
		vim.keymap.set("n", "<leader>fT", "<cmd>FzfLua tags<cr>", { desc = "fzf: workspaces tags" })
		vim.keymap.set("n", "<leader>fd", "<cmd>FzfLua  dap_variables<cr>", { desc = "fzf: active session variables" })
	end,
}
