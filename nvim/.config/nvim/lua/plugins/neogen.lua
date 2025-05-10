-- https://github.com/danymat/neogen

return {
	"danymat/neogen",
	cmd = "Neogen",
	keys = { "<Leader>/", desc = "Neogen" },
	config = function()
		require("neogen").setup({})

		local opts = { noremap = true, silent = true }
		vim.api.nvim_set_keymap("n", "<Leader>/", ":lua require('neogen').generate()<CR>", opts)
	end,
}
