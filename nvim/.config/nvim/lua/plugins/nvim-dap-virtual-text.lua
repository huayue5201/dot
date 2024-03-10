-- https://github.com/theHamsta/nvim-dap-virtual-text

return {
	"theHamsta/nvim-dap-virtual-text",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		require("nvim-dap-virtual-text").setup({
			virt_text_pos = "inline", -- 启用嵌入虚拟文本
		})
	end,
}
