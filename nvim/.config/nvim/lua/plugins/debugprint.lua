-- https://github.com/andrewferrier/debugprint.nvim

return {
	"andrewferrier/debugprint.nvim",
	lazy = false, -- Required to make line highlighting work before debugprint is first used
	version = "*", -- Remove if you DON'T want to use the stable version
	config = function()
		require("debugprint").setup({})
		vim.api.nvim_set_hl(0, "DebugPrintLine", { fg = "#ff0000", bg = "#333333" })
		-- 删除当前缓冲区中所有 debug print 语句
		vim.keymap.set(
			"n",
			"g?x",
			":Debugprint delete<CR>",
			{ noremap = true, desc = "Delete all debug prints" }
		)

		-- 注释/取消注释当前缓冲区中所有 debug print 语句
		vim.keymap.set(
			"n",
			"g?c",
			":Debugprint commenttoggle<CR>",
			{ noremap = true, desc = "Toggle comment debug prints" }
		)

		-- 重置 debug print 的持久计数器
		vim.keymap.set(
			"n",
			"g?r",
			":Debugprint resetcounter<CR>",
			{ noremap = true, desc = "Reset debug print counter" }
		)

		-- 搜索并填充 quickfix 列表
		vim.keymap.set(
			"n",
			"g?q",
			":Debugprint qflist<CR>",
			{ noremap = true, desc = "Debug prints to quickfix" }
		)
	end,
}
