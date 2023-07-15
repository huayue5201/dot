-- https://github.com/michaelb/sniprun

return {
	"michaelb/sniprun",
	build = "sh install.sh",
	ft = { "rust", "lua" },
	keys = {
		{ "<leader>ru", "<cmd>SnipRun<cr>", desc = "运行代码段" },
		{ "<leader>ru", "<cmd>'<,'>SnipRun<cr>", mode = "v", desc = "运行代码段" },
		{ "<leader>rd", "<cmd>SnipReset<cr>", desc = "终止运行" },
		{ "<leader>rc", "<cmd>SnipClose<cr>", desc = "清除运行结果" },
	},
	opts = {
		display = {
			-- "Classic", --# display results in the command-line  area
			"VirtualTextOk", --# display ok results as virtual text (multiline is shortened)

			-- "VirtualText",             --# display results as virtual text
			-- "TempFloatingWindow",      --# display results in a floating window
			-- "LongTempFloatingWindow",  --# same as above, but only long results. To use with VirtualText[Ok/Err]
			"Terminal", --# display results in a vertical split
			-- "TerminalWithCode",        --# display results and code history in a vertical split
			-- "NvimNotify",              --# display with the nvim-notify plugin
			-- "Api", --# return output to a programming interface
		},
	},
}
