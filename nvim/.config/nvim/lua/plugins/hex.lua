-- https://github.com/RaafatTurki/hex.nvim

return {
	"RaafatTurki/hex.nvim",
	keys = {
		{ "<localleader>h", desc = "进制转换" },
	},
	config = function()
		-- defaults
		require("hex").setup({

			-- cli command used to dump hex data
			dump_cmd = "xxd -g 1 -u",

			-- cli command used to assemble from hex data
			assemble_cmd = "xxd -r",

			-- function that runs on BufReadPre to determine if it's binary or not
			is_file_binary_pre_read = function()
				-- logic that determines if a buffer contains binary data or not
				-- must return a bool
			end,

			-- function that runs on BufReadPost to determine if it's binary or not
			is_file_binary_post_read = function()
				-- logic that determines if a buffer contains binary data or not
				-- must return a bool
			end,
		})
		vim.keymap.set(
			"n",
			"<localleader>h",
			"<cmd>lua require 'hex'.toggle()<CR>",
			{ silent = true, desc = "进制转换" }
		)
	end,
}
