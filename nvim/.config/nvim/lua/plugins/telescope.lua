-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	keys = {
		{ "<leader>of", "<cmd>Telescope find_files<cr>", desc = "文件检索" },
		{ "<leader>og", "<cmd>Telescope live_grep<cr>", desc = "字符检索" },
		{ "<leader>ob", "<cmd>Telescope buffers<cr>", desc = "buffers检索" },
		{ "<leader>oo", "<cmd>Telescope oldfiles<cr>", desc = "历史检索" },
	},
	config = function()
		-- https://github.com/folke/trouble.nvim 集成
		local trouble = require("trouble.providers.telescope")
		-- https://github.com/olimorris/persisted.nvim 集成
		require("telescope").load_extension("persisted")
		require("telescope").setup({
			defaults = {
				mappings = {
					i = { ["<c-t>"] = trouble.open_with_trouble },
					n = { ["<c-t>"] = trouble.open_with_trouble },
				},
			},
			extensions = {
				fzf = {
					fuzzy = true, -- false will only do exact matching
					override_generic_sorter = true, -- override the generic sorter
					override_file_sorter = true, -- override the file sorter
					case_mode = "smart_case", -- or "ignore_case" or "respect_case"
					-- the default case_mode is "smart_case"
				},
			},
		})
		-- fzf算法支持
		require("telescope").load_extension("fzf")
	end,
}
