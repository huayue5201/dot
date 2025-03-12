-- https://github.com/stevearc/quicker.nvim

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

	local icons = require("config.utils").icons.diagnostic
	require("quicker").setup({
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
			E = icons.ERROR,
			W = icons.WARN,
			I = icons.INFO,
			N = icons.INFO,
			H = icons.INFO,
		},
	})
end)
