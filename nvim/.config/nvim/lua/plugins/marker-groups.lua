-- https://github.com/jameswolensky/marker-groups.nvim

return {
	"jameswolensky/marker-groups.nvim",
	event = "VeryLazy",
	dependencies = {
		"nvim-lua/plenary.nvim", -- Required
		"ibhagwan/fzf-lua", -- Optional: fzf-lua picker
		-- mini.pick is part of mini.nvim; this plugin vendors mini.nvim for tests,
		-- but you can also install mini.nvim explicitly to use mini.pick system-wide
		-- "nvim-mini/mini.nvim",
	},
	config = function()
		require("marker-groups").setup({
			-- Default picker is 'vim' (built-in vim.ui)
			-- Accepted values: 'vim' | 'snacks' | 'fzf-lua' | 'mini.pick' | 'telescope'
			picker = "vim",
		})
	end,
}
