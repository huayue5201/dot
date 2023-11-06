-- https://github.com/linrongbin16/fzfx.nvim

return {
	"linrongbin16/fzfx.nvim",
	dependencies = { "junegunn/fzf", "nvim-tree/nvim-web-devicons" },
	event = "VeryLazy", -- keep for lazy loading
	config = function()
		require("fzfx").setup()
		vim.keymap.set("n", "<space>of", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true, desc = "文件索引" })
		vim.keymap.set(
			"x",
			"<space>of",
			"<cmd>FzfxFilesV<CR>",
			{ silent = true, noremap = true, desc = "文件索引" }
		)
		vim.keymap.set(
			"n",
			"<space>og",
			"<cmd>FzfxLiveGrep<cr>",
			{ silent = true, noremap = true, desc = "字符索引" }
		)
		vim.keymap.set(
			"x",
			"<space>og",
			"<cmd>FzfxLiveGrepV<cr>",
			{ silent = true, noremap = true, desc = "字符索引" }
		)
		vim.keymap.set(
			"n",
			"<space>bf",
			"<cmd>FzfxBuffers<cr>",
			{ silent = true, noremap = true, desc = "buffer索引" }
		)
		vim.keymap.set(
			"n",
			"<space>ol",
			"<cmd>FzfxFileExplorer<cr>",
			{ silent = true, noremap = true, desc = "文件管理" }
		)
	end,
}
