-- https://github.com/MeanderingProgrammer/render-markdown.nvim

return {
	"MeanderingProgrammer/render-markdown.nvim",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
		"bngarren/checkmate.nvim", -- 更好的复选框支持
	},
	ft = { "markdown", "Avante" },
	config = function()
		require("render-markdown").setup({
			file_types = { "markdown", "Avante" },
			render_modes = true,
			completions = { blink = { enabled = true } },
			preset = "obsidian",
			heading = { position = "inline" },
			-- checkbox = { checked = { scope_highlight = "@markup.strikethrough" } },
			checkbox = { enabled = false },
		})
	end,
}
