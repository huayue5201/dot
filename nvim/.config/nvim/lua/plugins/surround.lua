-- https://github.com/kylechui/nvim-surround

return {
	"kylechui/nvim-surround",
	event = "VeryLazy",
	dependencies = {
		-- https://github.com/gregorias/nvim-surround-wk
		-- 集成which key插件的映射预览功能
		"gregorias/nvim-surround-wk",
		config = true,
	},
	config = function()
		require("nvim-surround").setup()
	end,
}
