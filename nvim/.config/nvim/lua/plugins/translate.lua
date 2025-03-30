-- https://github.com/uga-rosa/translate.nvim

return {
	"uga-rosa/translate.nvim",
	event = "BufReadPost",
	config = function()
		vim.keymap.set("n", "<leader>tlf", ":Translate ZH -output=floating<CR>", { noremap = true, silent = true })
		vim.keymap.set("x", "<leader>tlf", ":Translate  ZH -output=floating<CR>", { noremap = true, silent = true })
		-- vim.keymap.set("n", "<leader>es", ":Translate EN -output=split<CR>", { noremap = true, silent = true })
		-- vim.keymap.set("x", "<leader>es", ":Translate EN -output=split<CR>", { noremap = true, silent = true })
		-- vim.keymap.set(
		-- 	"n",
		-- 	"<leader>ei",
		-- 	":Translate EN -output=insert<CR>",
		-- 	{ noremap = true, silent = true }
		-- )
		-- vim.keymap.set(
		-- 	"x",
		-- 	"<leader>ei",
		-- 	":Translate EN -output=insert<CR>",
		-- 	{ noremap = true, silent = true }
		-- )
		-- vim.keymap.set(
		-- 	"n",
		-- 	"<leader>er",
		-- 	":Translate EN -output=replace<CR>",
		-- 	{ noremap = true, silent = true }
		-- )
		-- vim.keymap.set(
		-- 	"x",
		-- 	"<leader>er",
		-- 	":Translate EN -output=replace<CR>",
		-- 	{ noremap = true, silent = true }
		-- )
	end,
}
