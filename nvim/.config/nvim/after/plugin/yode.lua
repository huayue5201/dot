-- https://github.com/hoschi/yode-nvim?tab=readme-ov-file

vim.g.later(function()
	vim.g.add({ source = "huayue5201/yode-nvim", depends = { "nvim-lua/plenary.nvim" } })

	require("yode-nvim").setup({})

	vim.keymap.set(
		"n",
		"<Leader>yc",
		":YodeCreateSeditorFloating<CR>",
		{ noremap = true, silent = true, desc = "在浮动窗口中编辑选区" }
	)
	vim.keymap.set(
		"n",
		"<Leader>yr",
		":YodeCreateSeditorReplace<CR>",
		{ noremap = true, silent = true, desc = "在分割窗口中编辑选区" }
	)
	vim.keymap.set(
		"n",
		"<Leader>bd",
		":YodeBufferDelete<CR>",
		{ noremap = true, silent = true, desc = "删除当前缓冲区" }
	)
	vim.keymap.set(
		"n",
		"<C-W>r",
		":YodeLayoutShiftWinDown<CR>",
		{ noremap = true, silent = true, desc = "将窗口向下移动" }
	)
	vim.keymap.set(
		"n",
		"<C-W>R",
		":YodeLayoutShiftWinUp<CR>",
		{ noremap = true, silent = true, desc = "将窗口向上移动" }
	)
	vim.keymap.set(
		"n",
		"<C-W>J",
		":YodeLayoutShiftWinBottom<CR>",
		{ noremap = true, silent = true, desc = "将窗口移动到底部" }
	)
	vim.keymap.set(
		"n",
		"<C-W>K",
		":YodeLayoutShiftWinTop<CR>",
		{ noremap = true, silent = true, desc = "将窗口移动到顶部" }
	)
end)
