-- https://github.com/kicanter/candela.nvim

return {
	"kicanter/candela.nvim",
	event = "VeryLazy",
	config = function()
		require("candela").setup()
		vim.keymap.set("n", "<leader>zdo", "<Plug>CandelaUi")
		vim.keymap.set("n", "<leader>zdr", "<Plug>CandelaRefresh")
		vim.keymap.set("n", "<leader>zdd", "<Plug>CandelaClear")
		vim.keymap.set("n", "<leader>zdl", "<Plug>CandelaLightbox")
		vim.keymap.set("n", "<leader>zdh", "<Plug>CandelaHelp")
	end,
}
