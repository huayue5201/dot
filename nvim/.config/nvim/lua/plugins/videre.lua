-- https://github.com/Owen-Dechow/videre.nvim?tab=readme-ov-file

return {
	"Owen-Dechow/videre.nvim",
	ft = { "json", "toml", "yaml" },
	cmd = "Videre",
	dependencies = {
		"Owen-Dechow/graph_view_yaml_parser", -- Optional: add YAML support
		"Owen-Dechow/graph_view_toml_parser", -- Optional: add TOML support
		"a-usr/xml2lua.nvim", -- Optional | Experimental: add XML support
	},
	config = function()
		require("videre").setup({
			-- set the window editor type
			editor_type = "split", -- split, floating
			round_units = false,
			simple_statusline = true, -- If you are just starting out with Videre,
			--   setting this to `false` will give you
			--   descriptions of available keymaps.
			-- Character used to represent empty space
			space_char = "-",
		})
		vim.keymap.set("n", "<leader>lv", "<cmd>Videre<CR>")
	end,
}
