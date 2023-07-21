-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy", -- keep for lazy loading
	version = "*",
	keys = {
		-- 切换到下一个buffer
		{ "<TAB>", "<cmd>BufferLineCycleNext<cr>" },
		-- 切换到上一个buffer
		{ "<S-TAB>", "<cmd>BufferLineCyclePrev<cr>" },
	},
	opts = {
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
					filetype = "neo-tree",
					text = "            File Explorer",
					highlight = "Directory",
					text_align = "left",
				},
				{
					filetype = "aerial",
					text = "󰡱 Symbols Outline     ",
					highlight = "Directory",
					text_align = "right",
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
	},
}
