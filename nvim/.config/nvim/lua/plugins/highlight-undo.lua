-- https://github.com/tzachar/highlight-undo.nvim

return {
	"tzachar/highlight-undo.nvim",
	event = "VeryLazy",
	config = function()
		require("highlight-undo").setup({
			hlgroup = "HighlightUndo",
			duration = 400,
			pattern = { "*" },
			ignored_filetypes = { "neo-tree", "fugitive", "TelescopePrompt", "mason", "lazy", "NvimTree" },
			-- ignore_cb is in comma as there is a default implementation. Setting
			-- to nil will mean no default os called.
			-- ignore_cb = nil,
		})
	end,
}
