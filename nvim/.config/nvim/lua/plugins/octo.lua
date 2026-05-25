-- https://github.com/pwntester/octo.nvim#-installation

return {
	"pwntester/octo.nvim",
	cmd = "Octo",
	keys = {
		{
			"<leader>ooi",
			"<CMD>Octo issue list<CR>",
			desc = "List GitHub Issues",
		},
		{
			"<leader>oop",
			"<CMD>Octo pr list<CR>",
			desc = "List GitHub PullRequests",
		},
		{
			"<leader>ood",
			"<CMD>Octo discussion list<CR>",
			desc = "List GitHub Discussions",
		},
		{
			"<leader>oon",
			"<CMD>Octo notification list<CR>",
			desc = "List GitHub Notifications",
		},
		{
			"<leader>oos",
			function()
				require("octo.utils").create_base_search_command({ include_current_repo = true })
			end,
			desc = "Search GitHub",
		},
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("octo").setup({
			-- or "fzf-lua" or "snacks" or "default"
			-- picker = "",
			-- bare Octo command opens picker of commands
			enable_builtin = true,
		})
	end,
}
