-- https://github.com/xieyonn/spinner.nvim

return {
	"xieyonn/spinner.nvim",
	event = "VeryLazy",
	config = function()
		---@type spinner
		local sp = require("spinner")

		-- NO need to call setup() if you are fine with defaults.
		sp.setup()

		require("spinner").config("cursor", {
			kind = "cursor", -- kind cursor
			attach = {
				lsp = {
					request = {
						-- select the methods you're interested in. For a complete list: `:h lsp-method`
						-- "textDocument/definition", -- for GoToDefinition (shortcut `C-]`)
						"textDocument/hover", -- for hover (shortcut `K`)
					},
				},
			},
		})
	end,
}
