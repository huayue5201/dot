-- https://github.com/hoschi/yode-nvim?tab=readme-ov-file

return {
	"huayue5201/yode-nvim",
	event = "BufReadPost",
	dependencies = "nvim-lua/plenary.nvim",
	config = function()
		require("yode-nvim").setup({})

		vim.keymap.set(
			{ "n", "x" },
			"<Leader>oc",
			":YodeCreateSeditorFloating<CR>",
			{ silent = true, desc = "在浮动窗口中编辑选区" }
		)
		vim.keymap.set(
			"n",
			"<Leader>or",
			":YodeCreateSeditorReplace<CR>",
			{ silent = true, desc = "在分割窗口中编辑选区" }
		)
		vim.keymap.set("n", "<C-W>r", ":YodeLayoutShiftWinDown<CR>", { silent = true, desc = "将窗口向下移动" })
		vim.keymap.set("n", "<C-W>R", ":YodeLayoutShiftWinUp<CR>", { silent = true, desc = "将窗口向上移动" })
		vim.keymap.set(
			"n",
			"<C-W>J",
			":YodeLayoutShiftWinBottom<CR>",
			{ silent = true, desc = "将窗口移动到底部" }
		)
		vim.keymap.set(
			"n",
			"<C-W>K",
			":YodeLayoutShiftWinTop<CR>",
			{ silent = true, desc = "将窗口移动到顶部" }
		)
	end,
}
