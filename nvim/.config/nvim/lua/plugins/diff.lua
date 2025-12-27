-- https://github.com/jake-stewart/diff.nvim

return {
	"jake-stewart/diff.nvim",
	event = "BufReadPost",
	config = function()
		require("diff").setup({
			unified = false,
			split = "below",
			cursorline = false,
		})
		vim.keymap.set("n", "<localleader>D", ":Diff<CR>", { noremap = true, silent = true })
	end,
}
