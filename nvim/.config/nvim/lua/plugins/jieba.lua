-- https://github.com/kkew3/jieba.vim

return {
	"kkew3/jieba.vim",
	tag = "v2.1.0",
	build = ":call jieba_vim#install()",
	init = function()
		vim.g.jieba_vim_lazy = 1
		vim.g.jieba_vim_keymap = 1
	end,
}
