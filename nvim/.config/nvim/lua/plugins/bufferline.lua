-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local bufferline = require("bufferline")
		bufferline.setup({
			options = {
				-- 显示缓冲区或者显示选项卡
				mode = "buffers",
				-- 是否允许覆盖高亮组
				themable = true,
				-- 将分隔符样式更改为thick
				separator_style = "thick",
				-- 组合样式预设
				-- style_preset = {
				-- bufferline.style_preset.minimal,
				-- bufferline.style_preset.no_bold,
				-- bufferline.style_preset.no_italic
				-- },
				-- 控制显示缓冲区编号的方式
				numbers = "none", -- "none" | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
				-- 设置缓冲区指示器的样式
				indicator = {
					icon = "▎",
					style = "icon", --| "underline" | "none",
				},
				-- 诊断
				diagnostics = "nvim_lsp",
				-- 鼠标悬停事件
				hover = {
					enabled = true,
					delay = 50,
					reveal = { "close" },
				},
				-- 特殊窗口占用
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						highlight = "Directory",
						text_align = "center",
					},
					{
						filetype = "aerial",
						text = "Symbol Tree",
						highlight = "Directory",
						text_align = "center",
					},
				},
			},
		})
		vim.keymap.set("n", "<leader>tx", "<cmd>BufferLineTogglePin<cr>", { desc = "标记buffer" })
	end,
}
