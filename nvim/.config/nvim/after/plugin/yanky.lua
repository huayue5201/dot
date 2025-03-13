-- https://github.com/gbprod/yanky.nvim

vim.g.later(function()
	vim.g.add({ source = "gbprod/yanky.nvim" })

	require("yanky").setup({
		highlight = {
			on_put = true,
			on_yank = true,
			timer = 500,
		},
		preserve_cursor_position = {
			enabled = true,
		},
	})
	vim.keymap.set("n", "<c-=>", "<Plug>(YankyPreviousEntry)")
	vim.keymap.set("n", "<c-->", "<Plug>(YankyNextEntry)")
	vim.keymap.set({ "n", "x" }, "y", "<Plug>(YankyYank)")
end)
