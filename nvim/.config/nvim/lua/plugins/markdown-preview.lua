-- https://github.com/iamcco/markdown-preview.nvim

return {
	"iamcco/markdown-preview.nvim",
	cmd = { "MarkdownPreviewToggle", "MarkdownPreview", "MarkdownPreviewStop" },
	ft = { "markdown" },
	build = function()
		vim.fn["mkdp#util#install"]()
	end,
	config = function()
		vim.cmd([[
      " set to 1, the nvim will auto close current preview window when changing
      " from Markdown buffer to another buffer
      " default: 1
         let g:mkdp_auto_close = 0
      ]])
	end,
}
