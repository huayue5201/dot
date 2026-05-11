-- https://github.com/rest-nvim/rest.nvim

return {
	"rest-nvim/rest.nvim",
	ft = "http",
	build = false,
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-treesitter/nvim-treesitter",
		{
			-- Lazy.nvim does not recognize this library's rocksfile, so add it
			-- to package path manually.
			"manoelcampos/xml2lua",
			config = function(plugin)
				package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
			end,
		},
		-- "lunarmodules/lua-mimetypes",
	},
}
