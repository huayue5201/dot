-- https://github.com/folke/ts-comments.nvim
-- 增强Neovim原生评论

return {
	"folke/ts-comments.nvim",
	opts = {},
	event = "BufReadPost",
	enabled = vim.fn.has("nvim-0.10.0") == 1,
}
