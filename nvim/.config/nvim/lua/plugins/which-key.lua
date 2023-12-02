-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	init = function()
		vim.o.timeout = true
		vim.o.timeoutlen = 500
	end,
	config = function()
		require("which-key").setup({
			-- window = {
			-- 	border = "double",
			-- },
			layout = {
				align = "center",
			},
		})
		local wk = require("which-key")
		wk.register({
			["<leader>o"] = {
				name = "Open...",
			},
			["<leader>c"] = {
				-- name = "Close...",
			},
			["<leader>t"] = {
				-- name = "Toggle...",
			},
		})
	end,
}
