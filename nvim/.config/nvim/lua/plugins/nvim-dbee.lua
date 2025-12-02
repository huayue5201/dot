-- https://github.com/kndndrj/nvim-dbee

return {
	"kndndrj/nvim-dbee",
	event = "VeryLazy",
	dependencies = {
		"MunifTanjim/nui.nvim",
	},
	build = function()
		-- Install tries to automatically detect the install method.
		-- if it fails, try calling it with one of these parameters:
		--    "curl", "wget", "bitsadmin", "go"
		require("dbee").install()
	end,
	config = function()
		require("dbee").setup(--[[optional config]])
		vim.keymap.set(
			"n",
			"<leader>od",
			"<cmd>lua require('dbee').toggle()<cr>",
			{ desc = "dbee: 打开数据管理" }
		)
	end,
}
