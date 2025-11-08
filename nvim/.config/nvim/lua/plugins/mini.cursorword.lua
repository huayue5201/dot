-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-cursorword.md

return {
	"nvim-mini/mini.cursorword",
	event = "VeryLazy",
	config = function()
		require("mini.cursorword").setup({
			-- delay: delay (in ms) between when cursor stops and when highlighting is applied
			delay = 100,
			-- filetype_allowlist: list of filetypes where highlighting is enabled
			-- empty means no restrictions
			filetype_allowlist = {},
			-- filetype_denylist: list of filetypes where highlighting is disabled
			-- empty means no restrictions
			filetype_denylist = { "dirbuf", "dirvish", "fugitive", "gitgraph", "NvimTree" },
			-- buftype_allowlist: list of buffer types where highlighting is enabled
			-- empty means no restrictions
			buftype_allowlist = {},
			-- buftype_denylist: list of buffer types where highlighting is disabled
			-- empty means no restrictions
			buftype_denylist = { "terminal", "nofile" },
		})
	end,
}
