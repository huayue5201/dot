-- https://github.com/chrisgrieser/nvim-rip-substitute

return {
	"chrisgrieser/nvim-rip-substitute",
	event = "VeryLazy",
	-- cmd = "RipSubstitute",
	config = function()
		require("rip-substitute").setup()

		vim.keymap.set({ "n", "x" }, "<leader>sgb", function()
			require("rip-substitute").sub()
		end, { desc = " rip substitute" })
	end,
}
