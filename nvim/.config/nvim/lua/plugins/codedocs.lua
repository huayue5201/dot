-- https://github.com/jeangiraldoo/codedocs.nvim

return {
	"jeangiraldoo/codedocs.nvim",
	event = "VeryLazy",
	config = function()
		vim.keymap.set("n", "gcd", "<cmd>Codedocs<CR>", { desc = "Insert annotation" })
	end,
}
