-- https://github.com/johmsalas/text-case.nvim

return {
	"johmsalas/text-case.nvim",
	config = function()
		require("textcase").setup({
			-- 默认使用 ga 前缀：gau/gal/gas/... 转换光标下单词。
			default_keymappings_enabled = true,
			prefix = "ga",
		})
	end,
}
