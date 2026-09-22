-- https://github.com/serhez/bento.nvim

return {
	"serhez/bento.nvim",
	config = function()
		require("bento").setup({
			ui = {
				mode = "floating", -- "floating" | "tabline"
			},
		})

		local api = require("bento.api")

		-- Register menu keymaps
		api.register_expand_key("<tab>") -- Open/expand menu
		api.register_last_buffer_key(";") -- Label for last-accessed buffer
		api.register_collapse_key("<Esc>") -- Collapse/close menu
		api.register_prev_page_key("[") -- Previous page (pagination)
		api.register_next_page_key("]") -- Next page (pagination)

		-- Register built-in actions (using built-in action functions)
		-- with example keymaps and highlights
		api.register_action("open", {
			key = "<CR>",
			action = api.actions.open,
			hl = "DiagnosticVirtualTextHint",
		})
		api.register_action("delete", {
			key = "<BS>",
			action = api.actions.delete,
			hl = "DiagnosticVirtualTextError",
		})
		api.register_action("vsplit", {
			key = "|",
			action = api.actions.vsplit,
			hl = "DiagnosticVirtualTextInfo",
		})
		api.register_action("split", {
			key = "_",
			action = api.actions.split,
			hl = "DiagnosticVirtualTextInfo",
		})
		api.register_action("lock", {
			key = "*",
			action = api.actions.lock,
			hl = "DiagnosticVirtualTextWarn",
		})

		-- Set default action
		api.set_default_action("open")
	end,
}
