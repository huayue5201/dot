-- https://github.com/chrisgrieser/nvim-origami

-- lazy.nvim
return {
	"chrisgrieser/nvim-origami",
	event = "VeryLazy",
	config = function()
		-- default settings
		require("origami").setup({
			useLspFoldsWithTreesitterFallback = true,
			pauseFoldsOnSearch = true,
			foldtext = {
				enabled = true,
				padding = 3,
				lineCount = {
					template = "%d lines", -- `%d` is replaced with the number of folded lines
					hlgroup = "Comment",
				},
				diagnosticsCount = true, -- uses hlgroups and icons from `vim.diagnostic.config().signs`
				gitsignsCount = true, -- requires `gitsigns.nvim`
				disableOnFt = { "snacks_picker_input" }, ---@type string[]
			},
			autoFold = {
				enabled = false,
				kinds = { "comment", "imports" }, ---@type lsp.FoldingRangeKind[]
			},
			foldKeymaps = {
				setup = true, -- modifies `h`, `l`, and `$`
				hOnlyOpensOnFirstColumn = false,
			},
		})
	end,
	-- recommended: disable vim's auto-folding
	init = function()
		vim.opt.foldlevel = 99
		vim.opt.foldlevelstart = 99
	end,
}
