-- https://github.com/mr-u0b0dy/crazy-coverage.nvim

return {
	"mr-u0b0dy/crazy-coverage.nvim",
	config = function()
		require("crazy-coverage").setup({
			-- 命中次数显示（覆盖率开启时默认显示，位置在行尾）
			hit_count = {
				show_by_default = true,
				display = "eol", -- "eol" | "inline" | "overlay" | "right_align" | "sign"
			},
			-- 自动适配当前配色主题（主题切换时覆盖率颜色跟随变化）
			auto_adapt_colors = true,
			-- 分支 overlay 标题里显示 taken/total 和百分比
			show_branch_summary = true,
		})

		-- 覆盖率映射：<leader>t 前缀，与 neotest 的测试映射保持一致
		vim.keymap.set("n", "<leader>tc", "<cmd>CoverageToggle<CR>", { desc = "切换覆盖率" })
		vim.keymap.set("n", "<leader>tg", "<cmd>CoverageSummary<CR>", { desc = "覆盖率汇总" })
		vim.keymap.set("n", "<leader>te", "<cmd>CoverageToggleNeoTree<CR>", { desc = "切换neotree覆盖率" })
	end,
}
