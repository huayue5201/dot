-- https://chatgpt.com/c/6912891d-5c50-832e-b554-1a77ad37b052
return {
	"nvim-mini/mini.starter",
	config = function()
		local starter = require("mini.starter")

		starter.setup({
			autoopen = true,
			evaluate_single = true,
			footer = "  " .. os.date("%Y-%m-%d %H:%M"),
		})
	end,
}
