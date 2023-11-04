-- https://github.com/sontungexpt/sttusline

return {
	"sontungexpt/sttusline",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	event = { "BufEnter" },
	config = function(_, opts)
		require("sttusline").setup({
			-- 0 | 1 | 2 | 3
			-- recommended: 3
			laststatus = 3,
			disabled = {
				filetypes = {
					-- "NvimTree",
					-- "lazy",
				},
				buftypes = {
					-- "terminal",
				},
			},
			components = {
				"mode",
				"filename",
				"git-branch",
				"git-diff",
				"%=",
				"diagnostics",
				"lsps-formatters",
				"copilot",
				"indent",
				"encoding",
				"pos-cursor",
				"pos-cursor-progress",
			},
		})
	end,
}
