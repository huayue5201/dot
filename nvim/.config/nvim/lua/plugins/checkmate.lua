-- https://github.com/bngarren/checkmate.nvim?tab=readme-ov-file

return {
	"bngarren/checkmate.nvim",
	ft = "markdown", -- Lazy loads for Markdown files matching patterns in 'files'
	dependencies = "MeanderingProgrammer/render-markdown.nvim",
	opts = {
		style = {
			checked_marker = { fg = "#7bff4f", bold = true },
		},
	},
}
