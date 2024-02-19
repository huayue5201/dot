-- https://github.com/nvim-pack/nvim-spectre

return {
	"nvim-pack/nvim-spectre",
	dependencies = "nvim-lua/plenary.nvim",
	keys = {
		{ "<leader>S", desc = "Toggle Spectre" },
		{ "<leader>osw", mode = { "n", "v" }, desc = "Search current word" },
		{ "<leader>osp", desc = "Search on current file" },
	},
	config = function()
		vim.keymap.set("n", "<leader>S", '<cmd>lua require("spectre").toggle()<CR>')
		vim.keymap.set("n", "<leader>osw", '<cmd>lua require("spectre").open_visual({select_word=true})<CR>')
		vim.keymap.set("v", "<leader>osw", '<esc><cmd>lua require("spectre").open_visual()<CR>')
		vim.keymap.set("n", "<leader>osp", '<cmd>lua require("spectre").open_file_search({select_word=true})<CR>')
	end,
}
