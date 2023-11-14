-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	event = "VeryLazy", -- keep for lazy loading
	dependencies = "nvim-lua/plenary.nvim",
	config = function()
		require("harpoon").setup({})
	end,
	vim.keymap.set("n", "<leader>a", [[<cmd>lua require("harpoon.mark").add_file()<CR>]], { desc = "添加书签" }),
	vim.keymap.set(
		"n",
		"<leader>ok",
		[[<cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>]],
		{ desc = "书签列表" }
	),
}
