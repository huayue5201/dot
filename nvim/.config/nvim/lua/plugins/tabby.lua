-- https://github.com/nanozuki/tabby.nvim

return {
	"nanozuki/tabby.nvim",
	event = "UIEnter",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		require("tabby").setup({
			-- theme = "oasis", -- Automatically matches your current Oasis style
		})

		vim.keymap.set("n", "<leader>trn", ":Tabby rename_tab ", { desc = "tabby: 重命名 Tab" })

		vim.keymap.set("n", "<leader>tp", ":Tabby pick_window<CR>", { desc = "tabby: Tab 列表", silent = true })
	end,
}
