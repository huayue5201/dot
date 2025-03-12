-- https://github.com/junegunn/vim-easy-align

vim.g.later(function()
	vim.g.add({ source = "junegunn/vim-easy-align" })

	-- 在可视模式下启动 EasyAlign
	vim.keymap.set("x", "gs", "<Plug>(EasyAlign)", { noremap = true, silent = true })

	-- 对于普通模式，启动 EasyAlign
	vim.keymap.set("n", "gs", "<Plug>(EasyAlign)", { noremap = true, silent = true })
end)
