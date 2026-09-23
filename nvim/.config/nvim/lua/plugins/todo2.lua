-- https://github.com/huayue5201/todo2

return {
	dir = "~/neovim-plugins/todo2",
	"huayue5201/todo2",
	dev = true,
	lazy = true,
	dependencies = { "nvim-store3" },
	name = "todo2",
	config = function()
		require("todo2").setup({
			conceal_enable = true, -- ✅ 顶层键，默认就是 true，其实可省略
		})
		vim.keymap.set("n", "<C-k>", "<cmd>SmartPreview<cr>", { desc = "todo2: todo预 览" })
		vim.keymap.set("n", "<leader>omh", "<cmd>Todo2Heatmap<cr>", { desc = "todo2: 热力图" })
	end,
}
