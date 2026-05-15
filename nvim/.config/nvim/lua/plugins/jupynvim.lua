-- https://github.com/sheng-tse/jupynvim

return {
	"sheng-tse/jupynvim",
	event = "VeryLazy",
	build = function(plugin)
		local install = loadfile(plugin.dir .. "/lua/jupynvim/install.lua")()
		install.run(plugin)
	end,
	config = function()
		require("jupynvim").setup({
			log_level = "info",
			image_renderer = "placeholder", -- "placeholder", "kitty", or "chafa"
		})
	end,
}
