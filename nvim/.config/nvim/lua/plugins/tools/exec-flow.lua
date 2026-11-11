-- https://github.com/huayue5201/exec-flow.nvim
-- 按执行顺序给代码行打编号锚点：<leader>xa/xl/xd/xc/xq、]x / [x
return {
	dir = "~/neovim-plugins/exec-flow.nvim",
	config = function()
		require("exec_flow").setup({
			keys = {
				add = "<leader>xa",
				list = "<leader>xl",
				delete = "<leader>xd",
				clear = "<leader>xc",
				qf = "<leader>xq",
				next = "]x",
				prev = "[x",
			},
		})
	end,
}
