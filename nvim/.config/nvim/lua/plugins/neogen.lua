-- https://github.com/danymat/neogen

return {
	"danymat/neogen",
	event = "VeryLazy",
	-- Uncomment next line if you want to follow only stable versions
	-- version = "*"
	config = function()
		require("neogen").setup({})
		local opts = { noremap = true, silent = true }
		vim.api.nvim_set_keymap("n", "gcn", ":lua require('neogen').generate()<CR>", opts)
	end,
}
