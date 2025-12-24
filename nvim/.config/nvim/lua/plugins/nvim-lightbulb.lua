-- https://github.com/kosayoda/nvim-lightbulb

return {
	"kosayoda/nvim-lightbulb",
	event = "LspAttach",
	config = function()
		-- vim.api.nvim_set_hl(0, "LightBulbFloatWin", {
		-- 	bg = "#FFD700",
		-- 	fg = "#FFD700", -- 字体颜色和背景一致 → 图标变成一个亮点
		-- })
		require("nvim-lightbulb").setup({
			autocmd = { enabled = true },
			-- 3. Floating window.
			float = {
				enabled = true,
				-- Text to show in the floating window.
				text = "💡",
				lens_text = "🔎",
				-- Highlight group to highlight the floating window.
				-- hl = "LightBulbFloatWin",
				-- Window options.
				-- See |vim.lsp.util.open_floating_preview| and |nvim_open_win|.
				-- Note that some options may be overridden by |open_floating_preview|.
				win_opts = {
					focusable = false,
					winblend = 100, -- 透明度
					border = "none",
				},
			},
			sign = {
				enabled = false,
				-- Text to show in the sign column.
				-- Must be between 1-2 characters.
				text = "💡",
				lens_text = "🔎",
				-- Highlight group to highlight the sign column text.
				hl = "LightBulbSign",
			},
		})
	end,
}
