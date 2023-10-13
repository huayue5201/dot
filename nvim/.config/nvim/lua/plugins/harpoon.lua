-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	dependencies = "nvim-lua/plenary.nvim",
	keys = {
		{ "<leader>a", [[<cmd>lua require("harpoon.mark").add_file()<cr>]], desc = "标记文件" },
		{ "<leader>ok", [[<cmd>lua require("harpoon.ui").toggle_quick_menu()<cr>]], desc = "标记列表" },
	},
	opts = {},
}
