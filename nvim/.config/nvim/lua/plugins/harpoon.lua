-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	dependencies = "nvim-lua/plenary.nvim",
	keys = {
		{ "<leader>b", [[<cmd>lua require("harpoon.mark").add_file()<CR>]], desc = "添加harpoon" },
		{ "<leader>oh", [[<cmd>lua require("harpoon.ui").toggle_quick_menu()<CR>]], desc = "harpoon列表" },
		{ "<leader>p", [[<cmd>lua require("harpoon.ui").nav_next()<CR>]], desc = "向前跳转harpoon" },
		{ "<leader>n", [[<cmd>lua require("harpoon.ui").nav_prev()<CR>]], desc = "向后跳转harpoon" },
		{ "<leader>1", [[<cmd>lua require("harpoon.ui").nav_file(1)<CR>]], desc = "跳转到harpoon 1" },
		{ "<leader>2", [[<cmd>lua require("harpoon.ui").nav_file(2)<CR>]], desc = "跳转到harpoon 2" },
		{ "<leader>3", [[<cmd>lua require("harpoon.ui").nav_file(3)<CR>]], desc = "跳转到harpoon 3" },
		{ "<leader>4", [[<cmd>lua require("harpoon.ui").nav_file(4)<CR>]], desc = "跳转到harpoon 4" },
		{ "<leader>5", [[<cmd>lua require("harpoon.ui").nav_file(5)<CR>]], desc = "跳转到harpoon 5" },
	},
	config = function()
		require("harpoon").setup({})
	end,
}
