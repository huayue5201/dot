-- https://github.com/nvim-telescope/telescope.nvim
-- 模糊搜索器

return {
	"nvim-telescope/telescope.nvim",
	cmd = "Telescope",
	keys = {
		{ "<leader>ff", "<cmd>Telescope find_files<cr>", desc = "文件查找" },
		{ "<leader>fg", "<cmd>Telescope live_grep<cr>", desc = "字符查找" },
		{ "<leader>fb", "<cmd>Telescope buffers<cr>", desc = "buff查找" },
		{ "<leader>fh", "<cmd>Telescope oldfiles<cr>", desc = "历史查找" },
		{ "<leader>fm", "<cmd>Telescope command_history<cr>", desc = "查找历史命令" },
		{ "<leader>fp", "<cmd>Telescope persisted<cr>", desc = "session管理" },
	},
	-- telescope扩展依赖
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- https://github.com/nvim-telescope/telescope-fzy-native.nvim
		"https://github.com/nvim-telescope/telescope-fzy-native.nvim",
	},
	config = function()
		-- persisted扩展
		require("telescope").load_extension("persisted")
		-- esc键退出
		local actions = require("telescope.actions")
		-- telescope配置
		require("telescope").setup({
			defaults = {
				vimgrep_arguments = {
					"rg",
					"--color=never",
					"--no-heading",
					"--with-filename",
					"--line-number",
					"--column",
					"--smart-case",
					"--trim", -- add this value
				},
				mappings = {
					i = {
						["<C-h>"] = "which_key",
					},
					n = {},
				},
			},
			-- UI配置
			pickers = {
				buffers = {
					mappings = {
						i = {
							["<c-d>"] = actions.delete_buffer + actions.move_to_top,
						},
					},
				},
			},
			extensions = {
				persisted = {
					layout_config = { width = 0.55, height = 0.55 },
				},
				fzy_native = {
					override_generic_sorter = true,
					override_file_sorter = true,
				},
			},
		})
		-- telescope-fzy-native
		require("telescope").load_extension("fzy_native")
	end,
}
