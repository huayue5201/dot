-- https://github.com/linrongbin16/fzfx.nvim

vim.g.later(function()
	vim.g.add({
		source = "linrongbin16/fzfx.nvim",
		depnds = { "nvim-tree/nvim-web-devicons" },
	})

	require("fzfx").setup()
	vim.keymap.set("n", "<space>ff", "<cmd>FzfxFiles<cr>", { silent = true, noremap = true, desc = "Find files" })
	-- live grep
	vim.keymap.set("n", "<space>fg", "<cmd>FzfxLiveGrep<cr>", { silent = true, noremap = true, desc = "Live grep" })
	-- by visual select
	vim.keymap.set(
		"x",
		"<space>fg",
		"<cmd>FzfxLiveGrep visual<cr>",
		{ silent = true, noremap = true, desc = "Live grep" }
	)
	-- by args
	vim.keymap.set("n", "<space>fb", "<cmd>FzfxBuffers<cr>", { silent = true, noremap = true, desc = "Find buffers" })
	vim.keymap.set("n", "<space>fm", "<cmd>FzfxMarks<cr>", { silent = true, noremap = true, desc = "Find files" })
end)
