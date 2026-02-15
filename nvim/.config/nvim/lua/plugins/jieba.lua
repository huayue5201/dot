-- https://github.com/messense/jieba-rs

return {
	"kkew3/jieba.vim",
	event = "VeryLazy",
	tag = "v1.0.5",
	build = "./build.sh",
	init = function()
		vim.g.jieba_vim_lazy = 1
		vim.g.jieba_vim_keymap = 1
	end,
}
