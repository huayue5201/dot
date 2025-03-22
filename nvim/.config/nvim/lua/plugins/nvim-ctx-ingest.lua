-- https://github.com/0xrusowsky/nvim-ctx-ingest

return {
	"0xrusowsky/nvim-ctx-ingest",
	keys = "<localleader>a",
	cmd = "CtxIngest",
	dependencies = "nvim-tree/nvim-web-devicons", -- required for file icons
	config = function()
		require("nvim-ctx-ingest").setup({
			window = {
				position = "float",
				width = 100,
				height = 40,
			},

			columns = {
				size = true,
				last_modified = true,
			},

			icons = {
				folder = {
					closed = "",
					open = "",
					empty = "",
					empty_open = "",
				},
				default = "",
				selected = "✓",
				unselected = " ",
			},

			max_file_size = 10 * 1024 * 1024, -- 10MB max file size

			ignore_patterns = {
				"%.env",
				"^%.git/",
				"%.svn/",
				"%.hg/",
				"node_modules/",
				"target/",
				"dist/",
				"build/",
				"%.pyc$",
				"__pycache__/",
				"%.egg%-info/",
				"%.vscode/",
				"%.idea/",
				"%.DS_Store$",
				"%.gitignore",
				"%.lock",
				-- Add your own patterns here
			},

			gitignore = {
				respect = true, -- Whether to respect .gitignore patterns
				auto_add = true, -- Whether to add output file to .gitignore
			},

			patterns = {
				include = {}, -- Default include patterns
				exclude = {}, -- Default exclude patterns
			},

			output = {
				save_file = false, -- Whether to save digest to file
				copy_clipboard = true, -- Whether to copy to clipboard
			},
		})
		vim.keymap.set("n", "<localleader>a", "<cmd>CtxIngest<cr>", { desc = "AI上下文复制" })
	end,
}
