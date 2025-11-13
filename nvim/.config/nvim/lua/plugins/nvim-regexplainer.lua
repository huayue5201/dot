-- https://github.com/bennypowers/nvim-regexplainer

return {
	"bennypowers/nvim-regexplainer",
	event = "BufReadPost",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"MunifTanjim/nui.nvim",
	},
	config = function()
		-- defaults
		require("regexplainer").setup({
			-- 'narrative', 'graphical'
			mode = "narrative",

			-- automatically show the explainer when the cursor enters a regexp
			auto = false,

			-- filetypes (i.e. extensions) in which to run the autocommand
			filetypes = {
				"html",
				"js",
				"cjs",
				"mjs",
				"ts",
				"jsx",
				"tsx",
				"cjsx",
				"mjsx",
			},

			-- Whether to log debug messages
			debug = false,

			-- 'split', 'popup'
			display = "popup",

			mappings = {
				toggle = "gR",
				-- examples, not defaults:
				-- show = 'gS',
				-- hide = 'gH',
				-- show_split = 'gP',
				-- show_popup = 'gU',
			},

			narrative = {
				indendation_string = "> ", -- default '  '
			},

			graphical = {
				width = 800, -- image width in pixels
				height = 600, -- image height in pixels
				python_cmd = nil, -- python command (auto-detected)
			},

			deps = {
				auto_install = true, -- automatically install Python dependencies
				python_cmd = nil, -- python command (auto-detected)
				venv_path = nil, -- virtual environment path (auto-generated)
				check_interval = 3600, -- dependency check interval in seconds
			},
		})
	end,
}
