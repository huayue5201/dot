-- https://github.com/v1nh1shungry/biquge.nvim

return {
	"v1nh1shungry/biquge.nvim",
	keys = {
		{
			"<Leader>o/",
			function()
				require("biquge").search()
			end,
			desc = "Search",
		},
		{
			"<Leader>ob",
			function()
				require("biquge").toggle()
			end,
			desc = "Toggle",
		},
		{
			"<Leader>ot",
			function()
				require("biquge").toc()
			end,
			desc = "Toc",
		},
		{
			"<Leader>on",
			function()
				require("biquge").next_chap()
			end,
			desc = "Next chapter",
		},
		{
			"<Leader>op",
			function()
				require("biquge").prev_chap()
			end,
			desc = "Previous chapter",
		},
		{
			"<Leader>os",
			function()
				require("biquge").star()
			end,
			desc = "Star current book",
		},
		{
			"<Leader>ol",
			function()
				require("biquge").bookshelf()
			end,
			desc = "Bookshelf",
		},
		{
			"<M-d>",
			function()
				require("biquge").scroll(1)
			end,
			desc = "Scroll down",
		},
		{
			"<M-u>",
			function()
				require("biquge").scroll(-1)
			end,
			desc = "Scroll up",
		},
		{
			"<M-'>",
			function()
				require("biquge").next_chap()
			end,
			desc = "Scroll up",
		},
		{
			"<M-;>",
			function()
				require("biquge").prev_chap()
			end,
			desc = "Scroll up",
		},
	},
	opts = {},
	config = function()
		require("biquge").setup({
			width = 30, -- 显示文本的宽度（字数）
			height = 10, -- 显示文本的行数
			hlgroup = "Comment", -- 高亮组
			bookshelf = vim.fs.joinpath(vim.fn.stdpath("data"), "biquge_bookshelf.json"), -- 书架存储路径
			-- * builtin: vim.ui.select
			-- * telescope
			-- * snacks
			picker = "builtin",
		})
	end,
}
