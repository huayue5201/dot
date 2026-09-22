-- https://github.com/oribarilan/lensline.nvim

return {
	"oribarilan/lensline.nvim",
	event = { "LspAttach", "BufWritePost" },
	config = function()
		require("lensline").setup({
			-- Profile configuration (first profile used as default)
			-- Note: omitting 'providers' or 'style' in a profile inherits defaults
			-- You can also override just specific properties (e.g., style = { placement = "inline" })
			profiles = {
				{
					name = "colorful",
					providers = {
						{ name = "usages", enabled = true, highlight = "Function" },
						{ name = "last_author", enabled = true, highlight = "String" },
					},
					style = {
						highlight = "Comment", -- fallback for providers without a highlight
					},
				},
			},
			-- global settings (apply to all profiles)
			limits = {
				-- exclude = {
				-- file patterns that lensline will not process for lenses
				-- see config.lua for extensive list of default patterns
				-- },
				exclude_append = {}, -- additional patterns to append to exclude list (empty by default)
				exclude_gitignored = true, -- respect .gitignore by not processing ignored files
				max_lines = 1000, -- process only first N lines of large files
				max_lenses = 70, -- skip rendering if too many lenses generated
			},
			debounce_ms = 500, -- unified debounce delay for all providers
			focused_debounce_ms = 150, -- debounce delay for focus tracking in focused mode
			silence_lsp = true, -- suppress noisy LSP log messages (e.g., Pyright reference spam)
			debug_mode = false, -- enable debug output for development, see CONTRIBUTE.md
		})
	end,
}
