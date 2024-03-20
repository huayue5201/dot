-- https://github.com/RutaTang/compter.nvim?tab=readme-ov-file

return {
	"RutaTang/compter.nvim",
	keys = { "<C-a>", "<C-x" },
	config = function()
		require("compter").setup({
			-- Provide and customize templates
			templates = {
				-- 字母
				{
					pattern = [[\l]],
					priority = 0,
					increase = function(content)
						local ansiCode = string.byte(content) + 1
						if ansiCode > string.byte("z") then
							ansiCode = string.byte("a")
						end
						local char = string.char(ansiCode)
						return char, true
					end,
					decrease = function(content)
						local ansiCode = string.byte(content) - 1
						if ansiCode < string.byte("a") then
							ansiCode = string.byte("z")
						end
						local char = string.char(ansiCode)
						return char, true
					end,
				},
				-- 布尔值
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
				-- for date format: dd/mm/YYYY
				{
					pattern = [[\d\{2}/\d\{2}/\d\{4}]],
					priority = 100,
					increase = function(content)
						local ts = vim.fn.strptime("%d/%m/%Y", content)
						if ts == 0 then
							return content, false
						else
							ts = ts + 24 * 60 * 60
							return vim.fn.strftime("%d/%m/%Y", ts), true
						end
					end,
					decrease = function(content)
						local ts = vim.fn.strptime("%d/%m/%Y", content)
						if ts == 0 then
							return content, false
						else
							ts = ts - 24 * 60 * 60
							return vim.fn.strftime("%d/%m/%Y", ts), true
						end
					end,
				},
			},
			-- Whether fallback to nvim-built-in increase and decrease operation, default to false
			fallback = true,
		})
	end,
}
