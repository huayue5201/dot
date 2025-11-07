-- https://github.com/jinh0/eyeliner.nvim

return {
	"jinh0/eyeliner.nvim",
	event = "VeryLazy", -- 延迟加载，启动后空闲时再加载
	config = function()
		require("eyeliner").setup({
			highlight_on_key = true, -- this must be set to true for dimming to work!
			dim = true,
		})
	end,
}
