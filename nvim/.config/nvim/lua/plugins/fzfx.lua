-- https://github.com/ibhagwan/fzf-lua

return {
	"linrongbin16/fzfx.nvim",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		"nvim-treesitter/nvim-treesitter",
		"junegunn/fzf",
	},
	keys = {
		{ "<leader>ff", mode = { "x", "n" }, desc = "Find files" },
		{ "<leader>fg", mode = { "x", "n" }, desc = "Live grep" },
		{ "<leader>fb", mode = "n", desc = "Find buffers" },
		{ "<leader>fw", mode = "n", desc = "Live grep by cursor word" },
	},
	config = function()
		require("fzfx").setup()
		-- by args
		vim.keymap.set("n", "<space>ff", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true })
		-- by visual select
		vim.keymap.set("x", "<space>ff", "<cmd>FzfxFiles visual<CR>", { silent = true, noremap = true })
		-- live grep
		vim.keymap.set("n", "<space>fg", "<cmd>FzfxLiveGrep<cr>", { silent = true, noremap = true })
		-- by visual select
		vim.keymap.set("x", "<space>fg", "<cmd>FzfxLiveGrep visual<cr>", { silent = true, noremap = true })
		-- by args
		vim.keymap.set("n", "<space>fb", "<cmd>FzfxBuffers<cr>", { silent = true, noremap = true })
		-- by cursor word
		vim.keymap.set("n", "<space>fw", "<cmd>FzfxLiveGrep cword<cr>", { silent = true, noremap = true })
	end,
}
