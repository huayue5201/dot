-- https://github.com/kylechui/nvim-surround
-- 使用快捷键配合textobjects快速地添加/修改/删除各种包括符，如()、[]、{}、<>等

return {
	"kylechui/nvim-surround",
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-treesitter/nvim-treesitter-textobjects",
	},
	keys = { "cs", "ds", "ys" },
	opts = {},
}
