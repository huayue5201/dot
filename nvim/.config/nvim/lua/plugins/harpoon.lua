-- https://github.com/ThePrimeagen/harpoon

return {
	"ThePrimeagen/harpoon",
	keys = {
		{ "<leader>a", [[<cmd>lua require("harpoon.mark").add_file()<cr>]], desc = "添加书签" },
		{ "<leader>p", [[<cmd>lua require("harpoon.ui").toggle_quick_menu()<cr>]], desc = "书签列表" },
		{ "<leader>tm", [[<cmd>lua require('harpoon.cmd-ui').toggle_quick_menu()<cr>]], desc = "命令列表" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
	},
	opts = {},
}
