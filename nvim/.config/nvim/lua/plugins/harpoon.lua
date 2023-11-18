-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	dependencies = "nvim-lua/plenary.nvim",
	keys = {
		{ "<leader>a", [[<cmd>lua require("harpoon.mark").add_file()<CR>]], desc = "添加书签" },
		{ "<leader>ok", [[<cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>]], desc = "书签列表" },
		{ "<leader>1", [[<cmd>lua require("harpoon.ui").nav_file(1)<CR>]], desc = "跳转到书签1" },
		{ "<leader>2", [[<cmd>lua require("harpoon.ui").nav_file(2)<CR>]], desc = "跳转到书签2" },
		{ "<leader>3", [[<cmd>lua require("harpoon.ui").nav_file(3)<CR>]], desc = "跳转到书签3" },
		{ "<leader>4", [[<cmd>lua require("harpoon.ui").nav_file(4)<CR>]], desc = "跳转到书签4" },
		{ "<leader>5", [[<cmd>lua require("harpoon.ui").nav_file(5)<CR>]], desc = "跳转到书签5" },
	},
	config = function()
		require("harpoon").setup({})
	end,
	vim.keymap.set(
		"n",
		"<leader>ok",
		[[<cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>]],
		{ desc = "书签列表" }
	),
}
