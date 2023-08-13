-- https://github.com/nvim-telescope/telescope.nvim

return {
	"nvim-telescope/telescope.nvim",
	tag = "0.1.2",
	dependencies = {
		"nvim-lua/plenary.nvim",
		-- https://github.com/nvim-telescope/telescope-fzy-native.nvim
		"nvim-telescope/telescope-fzy-native.nvim",
	},
	keys = {
		{ "<leader>f", "<cmd>Telescope find_files<cr>", desc = "文件检索" },
		{ "<leader>g", "<cmd>Telescope live_grep<cr>", desc = "字符检索" },
		{ "<leader>b", "<cmd>Telescope buffers<cr>", desc = "buffers检索" },
		{ "<leader>o", "<cmd>Telescope oldfiles<cr>", desc = "历史检索" },
	},
	config = function()
		require("telescope").setup({
			extensions = {
				fzy_native = {
					override_generic_sorter = false,
					override_file_sorter = true,
				},
			},
		})
		-- fzy算法支持
		require("telescope").load_extension("fzy_native")
	end,
}
