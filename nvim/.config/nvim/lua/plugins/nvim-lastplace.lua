-- https://github.com/huayue5201/nvim-lastplace

return {
	"huayue5201/nvim-lastplace",
	config = function()
		require("nvim-lastplace").setup({
			lastplace_ignore_buftype = { "quickfix", "nofile", "help" },
			lastplace_ignore_filetype = {
				"gitcommit",
				"gitrebase",
				"svn",
				"hgcommit",
				"blink-cmp-menu",
				"blink-cmp-docs",
			},
			lastplace_open_folds = true,
		})
	end,
}
