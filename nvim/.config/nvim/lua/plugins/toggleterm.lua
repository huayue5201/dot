-- https://github.com/akinsho/toggleterm.nvim

return {
	"akinsho/toggleterm.nvim",
	keys = { "<c-\\>" },
	config = function()
		require("toggleterm").setup({
			size = 25,
			open_mapping = [[<c-\>]],
			winbar = {
				enabled = true,
				name_formatter = function(term) --  term: Terminal
					return term.name
				end,
			},
		})

		vim.keymap.set({ "t", "n" }, "<c-w>\\", "<cmd>ToggleTermToggleAll<cr>", { desc = "Toggle terminal" })
	end,
}
