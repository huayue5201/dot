-- https://github.com/Owen-Dechow/videre.nvim

return {
	"Owen-Dechow/videre.nvim",
	cmd = "Videre",
	dependencies = {
		"Owen-Dechow/graph_view_yaml_parser", -- Optional: add YAML support
		"Owen-Dechow/graph_view_toml_parser", -- Optional: add TOML support
		"a-usr/xml2lua.nvim", -- Optional | Experimental: add XML support
	},
	keys = { { "<leader>zj", mode = { "n" }, "<cmd>Videre<cr>", desc = "videre: 图表查看" } },
	opts = {
		box_style = "sharp",
	},
	-- config = function()
	-- 	vim.keymap.set("n", "<leader>zj", "<cmd>Videre<cr>", { desc = "videre: 图表查看" })
	-- end,
}
