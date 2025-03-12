-- https://github.com/stevearc/quicker.nvim

local lsp_icons = require("config.utils").icons.diagnostic

vim.g.later(function()
	vim.g.add({ source = "stevearc/quicker.nvim" })

	vim.keymap.set("n", "<localleader>q", function()
		require("quicker").toggle()
	end, {
		desc = "Toggle quickfix",
	})
	vim.keymap.set("n", "<localleader>l", function()
		require("quicker").toggle({ loclist = true })
	end, {
		desc = "Toggle loclist",
	})

	require("quicker").setup({
		opts = {
			buflisted = true,
			number = true,
			relativenumber = false,
			signcolumn = "auto",
			winfixheight = true,
			wrap = true,
		},
		keys = {
			{
				">",
				function()
					require("quicker").expand({ before = 2, after = 2, add_to_existing = true })
				end,
				desc = "Expand quickfix context",
			},
			{
				"<",
				function()
					require("quicker").collapse()
				end,
				desc = "Collapse quickfix context",
			},
		},
		type_icons = {
			E = lsp_icons.ERROR,
			W = lsp_icons.WARN,
			I = lsp_icons.INFO,
			N = lsp_icons.INFO,
			H = lsp_icons.INFO,
		},
	})
end)
