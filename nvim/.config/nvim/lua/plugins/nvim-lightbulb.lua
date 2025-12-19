-- https://github.com/kosayoda/nvim-lightbulb

return {
	"kosayoda/nvim-lightbulb",
	event = "LspAttach",
	config = function()
		require("nvim-lightbulb").setup({
			autocmd = { enabled = true },
			-- 3. Floating window.
			float = {
				enabled = true,
				text = "💡",
				lens_text = "🔎",
				hl = "LightBulbFloatWin",
				win_opts = {
					focusable = false, -- 禁止窗口聚焦
					border = "none", -- 去掉边框
					blend = 0, -- 设置透明度（0 为完全透明）
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
