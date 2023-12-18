-- https://github.com/keaising/im-select.nvim
-- 需要外部工具支持https://github.com/daipeihust/im-select/blob/master/README_CN.md

return {
	"keaising/im-select.nvim",
	event = "VeryLazy",
	config = function()
		require("im_select").setup()
	end,
}
