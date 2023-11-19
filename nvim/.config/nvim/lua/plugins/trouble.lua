-- https://github.com/folke/trouble.nvim

return {
	"folke/trouble.nvim",
	event = { "BufReadPre" },
	dependencies = { "nvim-tree/nvim-web-devicons" },
	opts = {
		-- 打开列表自动折叠类容
		auto_fold = true,
		-- 启用lsp客户端定义的图标
		use_diagnostic_signs = true,
	},
	config = function()
		vim.keymap.set("n", "<leader>q", function()
			require("trouble").toggle()
		end)
	end,
}
