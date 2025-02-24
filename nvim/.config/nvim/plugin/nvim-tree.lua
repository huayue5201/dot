-- https://github.com/nvim-tree/nvim-tree.lua

vim.g.later(function()
	vim.g.add({
		source = "nvim-tree/nvim-tree.lua",
	})

	require("nvim-tree").setup({
		view = {
			width = 35,
		},
	})
	vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "文件树" })

	vim.cmd([[
    :hi      NvimTreeExecFile    guifg=#ffa0a0
    :hi      NvimTreeSpecialFile guifg=#ff80ff gui=underline
    :hi      NvimTreeSymlink     guifg=Yellow  gui=italic
    :hi link NvimTreeImageFile   Title
]])
end)
