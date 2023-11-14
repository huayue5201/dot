-- https://github.com/linrongbin16/fzfx.nvim

return {
	"linrongbin16/fzfx.nvim",
	event = "VeryLazy", -- keep for lazy loading
	dependencies = { "junegunn/fzf", "nvim-tree/nvim-web-devicons" },
	config = function()
		require("fzfx").setup()
		-- find files
		vim.keymap.set("n", "<space>of", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true, desc = "Find files" })
		-- live grep
		vim.keymap.set("n", "<space>og", "<cmd>FzfxLiveGrep<cr>", { silent = true, noremap = true, desc = "Live grep" })
		-- by visual select
		vim.keymap.set(
			"x",
			"<space>og",
			"<cmd>FzfxLiveGrepV<cr>",
			{ silent = true, noremap = true, desc = "Live grep" }
		)
		-- buffers
		vim.keymap.set(
			"n",
			"<space>ob",
			"<cmd>FzfxBuffers<cr>",
			{ silent = true, noremap = true, desc = "Find buffers" }
		)
	end,
}
