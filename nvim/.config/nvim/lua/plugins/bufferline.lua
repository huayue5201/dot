-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	dependencies = "nvim-tree/nvim-web-devicons",
	event = "VeryLazy",
	keys = {
		-- 切换到下一个buffer
		{ "<TAB>", "<cmd>BufferLineCycleNext<cr>" },
		-- 切换到上一个buffer
		{ "<S-TAB>", "<cmd>BufferLineCyclePrev<cr>" },
	},
	config = function()
		require("bufferline").setup({
			options = {
				mode = "buffers",
				numbers = "ordinal",
				-- 鼠标悬停事件
				hover = {
					enabled = true,
					delay = 0,
					reveal = { "close" },
				},
				toggle_hidden_on_enter = true,
				-- 侧边栏偏移设置
				offsets = {
					{
						filetype = "NvimTree",
						text = " File Explorer",
						highlight = "Directory",
						separator = true, -- use a "true" to enable the default, or set your own character
					},
					{
						filetype = "aerial",
						text = "󰡱 Symbols Outline",
						highlight = "Directory",
						separator = true, -- use a "true" to enable the default, or set your own character
					},
				},
				-- lsp支持
				diagnostics = "nvim_lsp",
				diagnostics_indicator = function(count, level, diagnostics_dict, context)
					if context.buffer:current() then
						return ""
					end
					return ""
				end,
			},
		})
	end,
}
