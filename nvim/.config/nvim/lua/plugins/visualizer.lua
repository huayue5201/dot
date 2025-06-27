-- https://github.com/nvimdev/visualizer.nvim

return {
	"nvimdev/visualizer.nvim",
	event = "LspAttach",
	config = function()
		vim.keymap.set("n", "grI", "<cmd>VisualizerIncoming<cr>", { desc = "显示调用这个的函数" })
		vim.keymap.set("n", "grO", "<cmd>VisualizerOutgoing<cr>", { desc = "显示这个调用的函数" })
		vim.keymap.set("n", "grF", "<cmd>VisualizerFull<cr>", { desc = "显示呼入和呼出电话" })
	end,
}
