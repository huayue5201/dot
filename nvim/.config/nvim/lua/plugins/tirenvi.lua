-- https://github.com/kibi2/tirenvi.nvim

return {
	"kibi2/tirenvi.nvim",
	ft = { "csv", "tsv", "pukiwiki" }, -- "markdown"

	dependencies = {
		"tpope/vim-repeat", -- optional: enables '.' repeat for column width operations
	},
	config = function()
		require("tirenvi").setup({
			parser_map = {
				csv = { executable = "tir-csv", required_version = "0.1.4" },
				tsv = { executable = "tir-csv", options = { "--delimiter", "\t" }, required_version = "0.1.4" },
				markdown = { executable = "tir-gfm-lite", allow_plain = true, required_version = "0.1.6" },
				pukiwiki = { executable = "tir-pukiwiki", allow_plain = true, required_version = "0.1.1" },
			},
		})

		vim.keymap.set("n", "<leader>zv", "<cmd>Tir toggle<cr>", { desc = "tirenvi: 开启/关闭" })
		-- vim.keymap.set({ "n", "o", "x" }, "<leader>tf", require("tirenvi").motion.f, { expr = true })
		-- vim.keymap.set({ "n", "o", "x" }, "<leader>tF", require("tirenvi").motion.F, { expr = true })
		-- vim.keymap.set({ "n", "o", "x" }, "<leader>tt", require("tirenvi").motion.t, { expr = true })
		-- vim.keymap.set({ "n", "o", "x" }, "<leader>tT", require("tirenvi").motion.T, { expr = true })
	end,
}
