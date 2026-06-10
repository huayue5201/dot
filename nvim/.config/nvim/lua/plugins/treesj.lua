-- https://github.com/Wansmer/treesj

return {
	"Wansmer/treesj",
	event = "VeryLazy",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("treesj").setup({
			use_default_keymaps = false, -- 禁用插件默认的键位
			check_syntax_error = true,
			max_join_length = 120,
			cursor_behavior = "hold",
			notify = true,
			dot_repeat = true,
		})

		-- 使用插件官方推荐的 gJ 和 gS，不干扰原生 gj/gk
		vim.keymap.set("n", "gJ", require("treesj").toggle, { desc = "TreeSJ: Join code block" })
		vim.keymap.set("n", "gS", require("treesj").split, { desc = "TreeSJ: Split code block" })
		--     vim.keymap.set('n', '<leader>M', function()
		--     require('treesj').toggle({ split = { recursive = true } })
		-- end)
	end,
}
