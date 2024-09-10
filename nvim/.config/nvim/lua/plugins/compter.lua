-- https://github.com/RutaTang/compter.nvim?tab=readme-ov-file

return {
	"RutaTang/compter.nvim",
	event = "BufReadPost",
	config = function()
		require("compter").setup({
			fallback = true,
			templates = {
				-- example template
				{
					pattern = [[\<\(true\|false\|TRUE\|FALSE\|True\|False\)\>]],
					priority = 100,
					increase = function(content)
						local switch = {
							["true"] = "false",
							["false"] = "true",
							["True"] = "False",
							["False"] = "True",
							["TRUE"] = "FALSE",
							["FALSE"] = "TRUE",
						}
						return switch[content], true
					end,
					decrease = function(content)
						local switch = {
							["true"] = "false",
							["false"] = "true",
							["True"] = "False",
							["False"] = "True",
							["TRUE"] = "FALSE",
							["FALSE"] = "TRUE",
						}
						return switch[content], true
					end,
				},
				-- STM32 HAL_GPIO高低电平切换
				{
					pattern = [[\<\(GPIO_PIN_SET\|GPIO_PIN_RESET\)\>]],
					priority = 100,
					increase = function(content)
						local switch = {
							["GPIO_PIN_SET"] = "GPIO_PIN_RESET",
							["GPIO_PIN_RESET"] = "GPIO_PIN_SET",
						}
						return switch[content], true
					end,
					decrease = function(content)
						local switch = {
							["GPIO_PIN_SET"] = "GPIO_PIN_RESET",
							["GPIO_PIN_RESET"] = "GPIO_PIN_SET",
						}
						return switch[content], true
					end,
				},
			},
		})
	end,
}
