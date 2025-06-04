-- https://github.com/folke/snacks.nvim

return {
	"folke/snacks.nvim",
	priority = 1000,
	lazy = false,
	---@type snacks.Config
	config = function()
		require("snacks").setup({
			-- your configuration comes here
			-- or leave it empty to use the default settings
			-- refer to the configuration section below
			amimate = { enabled = true },
			bigfile = { enabled = true },
			dashboard = { enabled = false },
			explorer = {
				enabled = true,
				replace_netrw = true,
			},
			image = { enabled = true },
			bufdelete = { enabled = true },
			indent = { enabled = true },
			input = { enabled = true },
			picker = { enabled = false },
			notifier = { enabled = false },
			quickfile = { enabled = true },
			scope = { enabled = false },
			scroll = { enabled = true },
			statuscolumn = { enabled = false },
			words = { enabled = true },
			terminal = { enabled = true },
			win = { enabled = false },
		})
		vim.keymap.set("n", "<leader>ef", function()
			Snacks.explorer()
		end, { silent = true, desc = "File Explorer" })
	end,
}
