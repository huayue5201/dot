-- https://github.com/DNLHC/glance.nvim

return {
	"dnlhc/glance.nvim",
	event = "VeryLazy",
	config = function()
		vim.keymap.set("n", "gD", "<CMD>Glance definitions<CR>", { desc = "Go to definition" })
		vim.keymap.set("n", "gR", "<CMD>Glance references<CR>", { desc = "Find references" })
		vim.keymap.set("n", "gY", "<CMD>Glance type_definitions<CR>", { desc = "Go to type definition" })
		vim.keymap.set("n", "gM", "<CMD>Glance implementations<CR>", { desc = "Find implementations" })
	end,
}
