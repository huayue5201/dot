-- https://github.com/kylesnowschwartz/prompt-tower.nvim

return {
	"kylesnowschwartz/prompt-tower.nvim",
	cmd = { "PromptTower", "PromptTowerSelect", "PromptTowerGenerate", "PromptTowerClear" },
	config = function()
		require("prompt-tower").setup({
			-- Configuration options (see below)
		})
	end,
}
