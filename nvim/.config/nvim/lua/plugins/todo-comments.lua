-- https://chatgpt.com/c/691e7a4d-bab4-8327-a4c7-3908d77a92f3

return {
	"folke/todo-comments.nvim",
	dependencies = { "nvim-lua/plenary.nvim" },
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		require("todo-comments").setup()

		-- 绑定快捷键
		vim.keymap.set("n", "]t", function()
			require("todo-comments").jump_next()
		end, { desc = "下一个 todo 注释" })
		vim.keymap.set("n", "[t", function()
			require("todo-comments").jump_prev()
		end, { desc = "上一个 todo 注释" })

		vim.keymap.set(
			"n",
			"<leader>tdl",
			"<cmd>TodoLocList<cr>",
			{ desc = "todo-comments: 在 LocList 中查找 todos" }
		)

		-- Trouble （如果你用了 trouble.nvim）
		vim.keymap.set(
			"n",
			"<leader>tdt",
			"<cmd>TodoTrouble<cr>",
			{ desc = "todo_comments: 在 Trouble 中显示 todos" }
		)
	end,
}
