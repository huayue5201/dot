-- https://github.com/xb-bx/editable-term.nvim

return {
	"xb-bx/editable-term.nvim",
	event = "VeryLazy",
	ft = "better_term",
	config = function()
		local editableterm = require("editable-term")
		editableterm.setup({
			promts = {
				["^%< "] = {},
				["^%> "] = {},
				["^%$ "] = {},
				["^%(gdb%) "] = {}, -- gdb promt
				["^>>> "] = {}, -- python PS1
				["^... "] = {}, -- python PS2
				["some_other_prompt"] = {
					keybinds = {
						clear_current_line = "keys to clear the line",
						goto_line_start = "keys to goto line start",
						forward_char = "keys to move forward one character",
					},
				},
			},
			wait_for_keys_delay = 50, -- amount of miliseconds to wait for shell to process keys
		})
	end,
}
