-- https://github.com/potamides/pantran.nvim

return {
	"potamides/pantran.nvim",
	keys = {
		{ "<leader>tr", desc = "文本翻译" },
		{ "<leader>trr", desc = "文本翻译" },
		{ "<leader>tr", mode = "x", desc = "文本翻译" },
	},
	config = function()
		require("pantran").setup({
			-- Default engine to use for translation. To list valid engine names run
			-- `:lua =vim.tbl_keys(require("pantran.engines"))`.
			default_engine = "google",
			-- Configuration for individual engines goes here.
			engines = {
				google = {
					default_source= "auto",
					default_target = "zh",
				},
			},
			controls = {
				mappings = {
					edit = {
						n = {
							-- Use this table to add additional mappings for the normal mode in
							-- the translation window. Either strings or function references are
							-- supported.
							["j"] = "gj",
							["k"] = "gk",
						},
						i = {
							-- Similar table but for insert mode. Using 'false' disables
							-- existing keybindings.
							["<C-y>"] = false,
							["<C-a>"] = require("pantran.ui.actions").yank_close_translation,
						},
					},
				},
			},
		})
		local opts = { noremap = true, silent = true, expr = true }
		vim.api.nvim_set_keymap("n", "<leader>tr", [[luaeval("require('pantran').motion_translate()")]], opts)
		vim.api.nvim_set_keymap("n", "<leader>trr", [[luaeval("require('pantran').motion_translate() .. '_'")]], opts)
		vim.api.nvim_set_keymap("x", "<leader>tr", [[luaeval("require('pantran').motion_translate()")]], opts)
	end,
}
