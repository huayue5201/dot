-- https://github.com/ThePrimeagen/harpoon/tree/harpoon2

return {
	"ThePrimeagen/harpoon",
	branch = "harpoon2",
	dependencies = "nvim-lua/plenary.nvim",
	keys = {
		{ "<leader>a", desc = "标记文件" },
		{ "<leader>oh", desc = "harpoon列表" },
		{ "<leader>1", desc = "跳转标记1" },
		{ "<leader>2", desc = "跳转标记2" },
		{ "<leader>3", desc = "跳转标记3" },
		{ "<leader>4", desc = "跳转标记4" },
	},
	config = function()
		local harpoon = require("harpoon")

		-- REQUIRED
		harpoon:setup()
		-- REQUIRED

		vim.keymap.set("n", "<leader>a", function()
			harpoon:list():append()
		end)

		vim.keymap.set("n", "<leader>oh", function()
			harpoon.ui:toggle_quick_menu(harpoon:list())
		end)

		vim.keymap.set("n", "<leader>1", function()
			harpoon:list():select(1)
		end)
		vim.keymap.set("n", "<leader>2", function()
			harpoon:list():select(2)
		end)
		vim.keymap.set("n", "<leader>3", function()
			harpoon:list():select(3)
		end)
		vim.keymap.set("n", "<leader>4", function()
			harpoon:list():select(4)
		end)
	end,
}
