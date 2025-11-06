-- https://github.com/Necrom4/convy.nvim

return {
	"necrom4/convy.nvim",
	cmd = "Convy",
	opts = {},
	config = function()
		require("convy").setup({
			-- default configuration
			notifications = true,
		})
	end,
	keys = {
		-- example keymaps
		{
			"<leader>cc",
			":Convy<CR>",
			desc = "Convert (interactive selection)",
			mode = { "n", "v" },
			silent = true,
		},
		{
			"<leader>cd",
			":Convy auto dec<CR>",
			desc = "Convert to decimal",
			mode = { "n", "v" },
			silent = true,
		},
	},
}
