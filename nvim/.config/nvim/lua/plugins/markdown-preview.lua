-- https://github.com/sammaji/markdown-preview.nvim

return {
	"sammaji/markdown-preview.nvim",
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
	keys = {
		{ "<leader>zm", "<cmd>MarkdownPreviewToggle<cr>", ft = "markdown", desc = "Markdown preview" },
	},
	ft = { "markdown" },
	opts = {},
}
