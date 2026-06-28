-- https://github.com/monkoose/matchparen.nvim

return {
	"monkoose/matchparen.nvim",
	event = "VeryLazy",
	config = function()
		require("matchparen").setup({
			-- Set to `false` to disable at matchpren at startup.
			-- Enable matchparen manually with `:MatchParenEnable`.
			enabled = true,
			-- Highlight group of the matched brackets.
			-- Change it to any other or adjust colors of "MathParen" highlight group
			-- in your colorscheme to your liking.
			hl_group = "MatchParen",
			-- Determines whether to skip searching for the brackets inside the closed folds.
			-- Generally, it should be left as default, because it's much faster and
			-- usually folds contain only the matched brackets, but if you often use some
			-- custom folds, you can set it to `false`.
			skip_folds = true,
		})
	end,
}
