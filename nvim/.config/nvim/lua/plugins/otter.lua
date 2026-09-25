-- https://github.com/jmbuhr/otter.nvim

return {
	"jmbuhr/otter.nvim",
	-- 在宿主文件类型打开时加载，保证 activate() 作用于当前文档
	ft = { "markdown", "quarto", "rmd" },
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		local otter = require("otter")
		otter.setup()

		-- 嵌入语言：markdown 代码块里要激活的语言
		-- 参数：languages, completion, diagnostics, tsquery
		otter.activate({ "python", "lua", "rust" }, true, false, nil)
	end,
}
