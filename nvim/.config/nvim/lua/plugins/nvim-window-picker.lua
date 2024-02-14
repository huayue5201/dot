-- https://github.com/s1n7ax/nvim-window-picker

return {
	"s1n7ax/nvim-window-picker",
	name = "window-picker",
	event = "WinNew",
	version = "2.*",
	config = function()
		require("window-picker").setup({ hint = "floating-big-letter" })
		vim.keymap.set("n", "<c-w>n", "<cmd>lua require('window-picker').pick_window()<cr>", { desc = "窗口跳转" })
	end,
}
