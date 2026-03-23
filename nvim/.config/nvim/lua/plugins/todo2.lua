-- https://github.com/huayue5201/todo2

return {
	dir = "~/todo2",
	"huayue5201/todo2",
	dev = true,
	-- event = "VeryLazy",
	lazy = true,
	dependencies = { "nvim-store3" },
	name = "todo2",
	config = function()
		require("todo2").setup({
			ui = {
				conceal = {
					enable = true,
				},
			},
		})
		vim.keymap.set("n", "<C-k>", "<cmd>SmartPreview<cr>", { desc = "todo2: todo预览" })
		vim.keymap.set("n", "<leader>at", "<cmd>Todo2AIToggle<cr>", { desc = "todo2: 切换为ai可执行标记" })
		vim.keymap.set("n", "<leader>ar", "<cmd>Todo2AIExecute<cr>", { desc = "todo2: 运行ai可执行标记" })
		vim.keymap.set(
			"n",
			"<leader>aR",
			"<cmd>Todo2AIExecuteAll<cr>",
			{ desc = "todo2: 批量运行ai可执行标记" }
		)
		vim.keymap.set("n", "<leader>af", "<cmd>TodoAISelectModel<cr>", { desc = "todo2: 选择ai模型" })
		vim.keymap.set("n", "<leader>ac", "<cmd>TodoAIStop<cr>", { desc = "todo2: 终止ai运行" })
	end,
}
