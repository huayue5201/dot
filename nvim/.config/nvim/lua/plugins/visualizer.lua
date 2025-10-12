-- https://github.com/nvimdev/visualizer.nvim

return {
	"nvimdev/visualizer.nvim",
	event = "LspAttach",
	config = function()
		vim.keymap.set("n", "grI", "<cmd>Visualizer incoming<cr>", { desc = "显示调用这个的函数" })
		vim.keymap.set("n", "grO", "<cmd>Visualizer outgoing<cr>", { desc = "显示这个调用的函数" })
		vim.keymap.set("n", "grF", "<cmd>Visualizer full<cr>", { desc = "显示呼入和呼出电话" })
		vim.keymap.set("n", "grS", "<cmd>Visualizer workspace_symbol<cr>", { desc = "显示lsp工作区符号" })
	end,
}
