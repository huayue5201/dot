-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.6",
	dependencies = {
		"nvim-lua/plenary.nvim",
		{ "nvim-telescope/telescope-fzf-native.nvim", build = "make" },
	},
	keys = {
		{ "<leader>ff", desc = "文件检索" },
		{ "<leader>fg", desc = "字符检索" },
		{ "<leader>fb", desc = "buffer检索" },
		{ "<leader>fw", desc = "光标下word检索" },
		{ "<leader>fo", desc = "历史文件检索" },
	},
	config = function()
		require("telescope").setup({
			extensions = {
				fzf = {
					fuzzy = true, -- false will only do exact matching
					override_generic_sorter = true, -- override the generic sorter
					override_file_sorter = true, -- override the file sorter
					case_mode = "smart_case", -- or "ignore_case" or "respect_case"
				},
			},
		})
		-- https://github.com/nvim-telescope/telescope-fzf-native.nvim
		require("telescope").load_extension("fzf")

		local builtin = require("telescope.builtin")
		vim.keymap.set("n", "<leader>ff", builtin.find_files, {})
		vim.keymap.set("n", "<leader>fg", builtin.live_grep, {})
		vim.keymap.set("n", "<leader>fb", builtin.buffers, {})
		vim.keymap.set("n", "<leader>fw", builtin.grep_string, {})
		vim.keymap.set("n", "<leader>fo", builtin.oldfiles, {})
	end,
}
