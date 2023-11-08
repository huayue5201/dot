-- https://github.com/ibhagwan/fzf-lua

return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy", -- keep for lazy loading
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	config = function()
		-- calling `setup` is optional for customization
		require("fzf-lua").setup({})
		vim.keymap.set(
			"n",
			"<leader>of",
			"<cmd>lua require('fzf-lua').files()<CR>",
			{ silent = true, desc = "文件检索" }
		)
		vim.keymap.set(
			"n",
			"<leader>ob",
			"<cmd>lua require('fzf-lua').buffers()<CR>",
			{ silent = true, desc = "buffer检索" }
		)
		vim.keymap.set(
			"n",
			"<leader>og",
			"<cmd>lua require('fzf-lua').grep()<CR>",
			{ silent = true, desc = "字符检索" }
		)
		vim.keymap.set(
			"x",
			"<leader>og",
			"<cmd>lua require('fzf-lua').grep_visual()<CR>",
			{ silent = true, desc = "字符检索" }
		)
		vim.keymap.set(
			"n",
			"<leader>oh",
			"<cmd>lua require('fzf-lua').oldfiles()<CR>",
			{ silent = true, desc = "历史检索" }
		)
	end,
}
