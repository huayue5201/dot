-- https://github.com/folke/flash.nvim

return {
	"folke/flash.nvim",
	event = "VeryLazy",
	config = function()
		require("flash").setup({
			modes = {
				char = {
					jump_labels = true,
				},
			},
		})

		-- 设置快捷键
		local map = vim.keymap.set

		map({ "n", "x", "o" }, "s", function()
			require("flash").jump()
		end, { desc = "Flash: 快速跳转" })

		map({ "n", "x", "o" }, "S", function()
			require("flash").treesitter()
		end, { desc = "Flash: Treesitter 节点" })

		map("o", "r", function()
			require("flash").remote()
		end, { desc = "Flash: 远程操作" })

		map({ "o", "x" }, "R", function()
			require("flash").treesitter_search()
		end, { desc = "Flash: Treesitter 搜索" })

		map("c", "<c-s>", function()
			require("flash").toggle()
		end, { desc = "Flash: 切换搜索" })
	end,
}
