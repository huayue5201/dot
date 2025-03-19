-- https://github.com/0xrusowsky/nvim-ctx-ingest

return {
	"0xrusowsky/nvim-ctx-ingest",
	keys = "<localleader>a",
	cmd = "CtxIngest",
	dependencies = {
		"echasnovski/mini.icons", -- required for file icons
	},
	config = function()
		require("nvim-ctx-ingest").setup({
			-- your config options here
		})

		vim.keymap.set("n", "<localleader>a", "<cmd>CtxIngest<cr>", { desc = "AI上下文复制" })
	end,
}
