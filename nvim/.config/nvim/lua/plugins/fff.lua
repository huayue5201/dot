-- https://github.com/dmtrKovalenko/fff

return {
	"dmtrKovalenko/fff.nvim",
	build = function()
		-- downloads a prebuilt binary or falls back to cargo build
		require("fff.download").download_or_build_binary()
	end,
	lazy = false, -- the plugin lazy-initialises itself
	config = function()
		require("fff").setup({
			debug = {
				enabled = true,
				show_scores = true,
			},
		})

		-- === Keymaps: ===
		vim.keymap.set("n", "<leader>ff", function()
			require("fff").find_files()
		end, { desc = "FFFind files" })

		vim.keymap.set("n", "<leader>fg", function()
			require("fff").live_grep()
		end, { desc = "LiFFFe grep" })

		vim.keymap.set("n", "<leader>fz", function()
			require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } })
		end, { desc = "Live fffuzy grep" })

		vim.keymap.set("n", "<leader>fc", function()
			require("fff").live_grep({ query = vim.fn.expand("<cword>") })
		end, { desc = "Search current word" })
	end,
}
