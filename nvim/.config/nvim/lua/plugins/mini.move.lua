-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-move.md

return {
	"nvim-mini/mini.move",
	version = "*",
	config = function()
		require("mini.move").setup( -- No need to copy this inside `setup()`. Will be used automatically.
			{
				-- Module mappings. Use `''` (empty string) to disable one.
				mappings = {
					-- Move visual selection in Visual mode. Defaults are Alt (Meta) + hjkl.
					left = "<M-h>",
					right = "<M-l>",
					down = "<M-j>",
					up = "<M-k>",

					-- Move current line in Normal mode
					line_left = "<M-h>",
					line_right = "<M-l>",
					line_down = "<M-j>",
					line_up = "<M-k>",
				},

				-- Options which control moving behavior
				options = {
					-- Automatically reindent selection during linewise vertical move
					reindent_linewise = true,
				},
			}
		)
	end,
}
