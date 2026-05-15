-- https://github.com/danymat/neogen
-- TODO:备选:https://github.com/jeangiraldoo/codedocs.nvim

return {
	"jeangiraldoo/codedocs.nvim",
	event = "VeryLazy",
	-- Uncomment next line if you want to follow only stable versions
	-- version = "*"
	config = function()
		require("codedocs").setup({
			debug = false,
			languages = {
				--- This table is too big to be displayed here
				--- The path to the config file is `codedocs/config/init.lua`
			},
			aliases = {
				sh = "bash",
			},
		})
		vim.keymap.set("n", "gcn", "<cmd>Codedocs<CR>", { desc = "Insert annotation" })
	end,
}
