-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	event = "VeryLazy",
	config = function()
		require("which-key").setup({
			preset = "helix",
		})

		vim.keymap.set("n", "<leader>?", function()
			require("which-key").show({ global = false })
		end, { desc = "Buffer Local Keymaps (which-key)" })
	end,
}
