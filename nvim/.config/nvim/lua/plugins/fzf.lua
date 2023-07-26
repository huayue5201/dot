-- https://github.com/ibhagwan/fzf-lua

return {
	"ibhagwan/fzf-lua",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>f", "<cmd>FzfLua files<cr>", desc = "文件检索" },
		{ "<leader>g", "<cmd>FzfLua grep<cr>", desc = "字符检索" },
		{ "<leader>o", "<cmd>FzfLua oldfiles<cr>", desc = "文件历史检索" },
		{ "<leader>b", "<cmd>FzfLua buffers<cr>", desc = "buffers检索" },
	},
	config = function()
		-- calling `setup` is optional for customization
		require("fzf-lua").setup({})
	end,
}
