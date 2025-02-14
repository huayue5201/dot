-- https://github.com/nvim-tree/nvim-tree.lua

vim.g.add({
	source = "nvim-tree/nvim-tree.lua",
	depnds = { "nvim-tree/nvim-web-devicons" },
})

vim.g.later(function()
require("nvim-tree").setup()
vim.keymap.set("n", "<leader>e", "<cmd>NvimTreeToggle<cr>", { desc = "文件树" })
end)
