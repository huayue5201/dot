-- https://github.com/ibhagwan/fzf-lua
-- WARN: 需依赖外部程序fzf(MACOS:brew install fzf)

return {
	"ibhagwan/fzf-lua",
	-- https://github.com/nvim-tree/nvim-web-devicons
	dependencies = { "nvim-tree/nvim-web-devicons" },
	keys = {
		{ "<leader>f", "<cmd>FzfLua files<cr>", desc = "文件检索" },
		{ "<leader>g", "<cmd>FzfLua grep<cr>", desc = "字符检索" },
		{ "<leader>o", "<cmd>FzfLua oldfiles<cr>", desc = "文件历史检索" },
		{ "<leader>b", "<cmd>FzfLua buffers<cr>", desc = "buffers检索" },
	},
	config = function()
		-- calling `setup` is optional for customization
		require("fzf-lua").setup({
			-- 窗口大小设置
			winopts_fn = function()
				-- smaller width if neovim win has over 80 columns
				return { width = vim.o.columns > 80 and 0.65 or 0.85 }
			end,
		})
	end,
}
