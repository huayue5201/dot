-- https://github.com/kevinhwang91/nvim-bqf

return {
	"kevinhwang91/nvim-bqf",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		{
			"junegunn/fzf",
			build = function()
				-- fzf#install() 定义在 plugin/fzf.vim 里；zpack 运行 build hook 时用
				-- `:packadd!`（跳过 plugin/ 脚本），所以先显式 packadd 再调用。
				vim.cmd("packadd fzf")
				vim.fn["fzf#install"]()
			end,
		},
	},
	ft = "qf",
}
