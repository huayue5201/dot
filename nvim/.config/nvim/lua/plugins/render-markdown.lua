-- https://github.com/MeanderingProgrammer/render-markdown.nvim

return {
	"MeanderingProgrammer/render-markdown.nvim",
	ft = { "markdown", "codecompanion" },
	dependencies = { "nvim-treesitter/nvim-treesitter", "nvim-tree/nvim-web-devicons" },
	config = function()
		require("render-markdown").setup({
			ignore = function(buf)
				local path = vim.api.nvim_buf_get_name(buf)
				-- 特定文件忽略渲染
				return string.find(path, "todo.md") ~= nil
			end,
			checkbox = {
				enabled = false,
			},
			completions = { lsp = { enabled = true } },
		})
	end,
}
