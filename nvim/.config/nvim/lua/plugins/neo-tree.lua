-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	{
		"nvim-neo-tree/neo-tree.nvim",
		branch = "v3.x",
		dependencies = {
			"nvim-lua/plenary.nvim",
			"MunifTanjim/nui.nvim",
			"nvim-tree/nvim-web-devicons", -- optional, but recommended
		},
		lazy = false, -- neo-tree will lazily load itself
		config = function()
			require("neo-tree").setup({
				close_if_last_window = true,
				popup_border_style = "rounded",
				window = {
					position = "left",
					width = 45,
					mapping_options = {
						noremap = true,
						nowait = true,
					},
					mappings = {
						["<space>"] = {
							"toggle_node",
							nowait = true, -- disable `nowait` if you have existing combos starting with this char that you want to use
						},
					},
				},
			})
			vim.keymap.set("n", "<leader>ef", "<Cmd>Neotree toggle<CR>")
			vim.keymap.set("n", "<leader>eb", "<Cmd>Neotree buffers toggle<CR>")
			vim.keymap.set("n", "<leader>eg", "<Cmd>Neotree git_status toggle<CR>")
		end,
	},
}
