-- https://github.com/DNLHC/glance.nvim

return {
	"dnlhc/glance.nvim",
	cmd = "Glance",
	config = function()
		vim.keymap.set("n", "grD", "<CMD>Glance definitions<CR>", { desc = "Glance: Go to definition" })
		vim.keymap.set("n", "grR", "<CMD>Glance references<CR>", { desc = "Glance: Find references" })
		vim.keymap.set("n", "grY", "<CMD>Glance type_definitions<CR>", { desc = "Glance: Go to type definition" })
		vim.keymap.set("n", "grM", "<CMD>Glance implementations<CR>", { desc = "Glance: Go to implementation" })
	end,
}
