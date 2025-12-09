-- https://github.com/XXiaoA/atone.nvim

return {
	"XXiaoA/atone.nvim",
	event = "VeryLazy",
	cmd = "Atone",
	config = function()
		require("atone").setup({
			layout = {
				---@type "left"|"right"
				direction = "left",
				---@type "adaptive"|integer|number
				--- adaptive: exact the width of tree graph
				--- if number given is a float less than 1, the width is set to `vim.o.columns * that number`
				width = 0.40,
			},
			-- diff for the node under cursor
			-- shown under the tree graph
			diff_cur_node = {
				enabled = true,
				---@type number float less than 1
				--- The diff window's height is set to a specified percentage of the original (namely tree graph) window's height.
				split_percent = 0.3,
			},
			-- automatically update the buffer that the tree is attached to
			-- only works for buffer whose buftype is <empty>
			auto_attach = {
				enabled = true,
				excluded_ft = { "oil" },
			},
			keymaps = {
				tree = {
					quit = { "<C-c>", "q" },
					next_node = "j", -- support v:count
					pre_node = "k", -- support v:count
					undo_to = "<CR>",
					help = { "?", "g?" },
				},
				auto_diff = {
					quit = { "<C-c>", "q" },
					help = { "?", "g?" },
				},
				help = {
					quit_help = { "<C-c>", "q" },
				},
			},
			ui = {
				-- refer to `:h 'winborder'`
				border = "double",
				-- compact graph style
				compact = false,
			},
		})
		vim.keymap.set("n", "<leader>eu", ":Atone toggle<CR>", { desc = "Toggle Atone undo tree" })
	end,
}
