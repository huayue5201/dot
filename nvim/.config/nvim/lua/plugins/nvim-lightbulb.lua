-- https://github.com/kosayoda/nvim-lightbulb

return {
	"kosayoda/nvim-lightbulb",
	event = "LspAttach",
	config = function()
		require("nvim-lightbulb").setup({
			autocmd = { enabled = true },
			sign = {
				enabled = true,
				-- Text to show in the sign column.
				-- Must be between 1-2 characters.
				text = "💡",
				lens_text = "🔎",
				-- Highlight group to highlight the sign column text.
				hl = "LightBulbSign",
			},
		})
	end,
}
