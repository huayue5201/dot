-- https://github.com/shellRaining/hlchunk.nvim

return {
	"shellRaining/hlchunk.nvim",
	event = { "BufReadPre", "BufNewFile" },
	config = function()
		require("hlchunk").setup({
			exclude_filetypes = {
				aerial = true,
				dashboard = true,
				-- some other filetypes
			},
			chunk = {
				enable = true,
			},
			indent = {
				enable = true,
				style = {
					vim.api.nvim_get_hl(0, { name = "Whitespace" }),
				},
			},
			line_num = {
				enabled = true,
			},
			blank = {
				enabled = true,
			},
		})
	end,
}
