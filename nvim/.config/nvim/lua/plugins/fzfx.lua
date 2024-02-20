-- https://github.com/ibhagwan/fzf-lua

return {
	"linrongbin16/fzfx.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-treesitter/nvim-treesitter",
		"junegunn/fzf",
	},
	keys = {
		{ "<leader>of", mode = { "x", "n" }, desc = "Find files" },
		{ "<leader>og", mode = { "x", "n" }, desc = "Live grep" },
		{ "<leader>ob", mode = "n", desc = "Find buffers" },
		{ "<leader>oi", mode = "n", desc = "Live grep by cursor word" },
	},
	config = function()
		require("fzfx").setup()
		-- by args
		vim.keymap.set("n", "<space>of", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true })
		-- by visual select
		vim.keymap.set("x", "<space>of", "<cmd>FzfxFiles visual<CR>", { silent = true, noremap = true })
		-- live grep
		vim.keymap.set("n", "<space>og", "<cmd>FzfxLiveGrep<cr>", { silent = true, noremap = true })
		-- by visual select
		vim.keymap.set("x", "<space>og", "<cmd>FzfxLiveGrep visual<cr>", { silent = true, noremap = true })
		-- by args
		vim.keymap.set("n", "<space>ob", "<cmd>FzfxBuffers<cr>", { silent = true, noremap = true })
		-- by cursor word
		vim.keymap.set("n", "<space>oi", "<cmd>FzfxLiveGrep cword<cr>", { silent = true, noremap = true })
	end,
}
