-- https://github.com/NeogitOrg/neogit

return {
	"NeogitOrg/neogit",
	lazy = true,
	dependencies = {
		"nvim-lua/plenary.nvim", -- 必须
	},
	cmd = "Neogit",
	keys = {
		{ "<leader>gg", "<cmd>Neogit<cr>", desc = "neogit: Open Neogit" },
	},
	config = function()
		local neogit = require("neogit")
		neogit.setup({
			-- 窗口与布局
			kind = "split", -- 可选 "tab" | "split" | "vsplit" | "floating"

			-- "ascii"   is the graph the git CLI generates
			-- "unicode" is the graph like https://github.com/rbong/vim-flog
			-- "kitty"   is the graph like https://github.com/isakbm/gitgraph.nvim - use https://github.com/rbong/flog-symbols if you don't use Kitty
			graph_style = "kitty",
			-- Show message with spinning animation when a git command is running.
			process_spinner = false,
			-- Allows a different telescope sorter. Defaults to 'fuzzy_with_index_bias'. The example below will use the native fzf
			-- sorter instead. By default, this function returns `nil`.
			telescope_sorter = function()
				return require("telescope").extensions.fzf.native_fzf_sorter()
			end,
		})

		-- vim.keymap.set("n", "<leader>gg", "<cmd>Neogit<cr>", { desc = "Open Neogit UI" })
	end,
}
