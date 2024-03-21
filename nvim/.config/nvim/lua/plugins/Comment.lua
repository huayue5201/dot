-- https://github.com/numToStr/Comment.nvim

return {
	"numToStr/Comment.nvim",
	event = "BufReadPost",
	keys = {
		{ "gcc", desc = "行注释" },
		{ "gbc", desc = "块注释" },
		{ "gcO", desc = "添加注释(上)" },
		{ "gco", desc = "添加注释(下)" },
		{ "gcA", desc = "添加注释(后)" },
		{ "gc", mode = "v", desc = "行注释" },
		{ "gb", mode = "v", desc = "块注释" },
	},
	config = function()
		require("Comment").setup({
			-- 忽略空行
			ignore = "^$",
		})

		local ft = require("Comment.ft")

		ft.javascript = { "//%s", "/*%s*/" }
		ft.yaml = "#%s"
		ft({ "go", "rust" }, ft.get("c"))
		ft({ "toml", "graphql" }, "#%s")
	end,
}
