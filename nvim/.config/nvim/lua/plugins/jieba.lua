-- https://github.com/kkew3/jieba.vim

return {
	"kkew3/jieba.vim",
	dependencies = { "tpope/vim-repeat" },
	branch = "release",
	build = ":call jieba_vim#install()",
	init = function()
		vim.g.jieba_vim_lazy = 1
		vim.g.jieba_vim_keymap = 1
	end,
}
