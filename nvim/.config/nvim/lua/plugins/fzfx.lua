-- https://github.com/linrongbin16/fzfx.nvim

return {
	"linrongbin16/fzfx.nvim",
	event = "VeryLazy",
	dependencies = { "junegunn/fzf", "nvim-tree/nvim-web-devicons" },
	config = function()
		require("fzfx").setup()
		-- find files
		vim.keymap.set("n", "<space>of", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true, desc = "文件检索" })
		-- live grep
		vim.keymap.set(
			"n",
			"<space>og",
			"<cmd>FzfxLiveGrep<cr>",
			{ silent = true, noremap = true, desc = "字符检索" }
		)
		-- by visual select
		vim.keymap.set(
			"x",
			"<space>og",
			"<cmd>FzfxLiveGrepV<cr>",
			{ silent = true, noremap = true, desc = "字符检索" }
		)
		-- buffers
		vim.keymap.set(
			"n",
			"<space>ob",
			"<cmd>FzfxBuffers<cr>",
			{ silent = true, noremap = true, desc = "buffer检索" }
		)
	end,
}
