-- https://github.com/jeangiraldoo/codedocs.nvim

return {
	"jeangiraldoo/codedocs.nvim",
	config = function()
		vim.keymap.set("n", "gcd", "<cmd>Codedocs<CR>", { desc = "Insert annotation" })
	end,
}
