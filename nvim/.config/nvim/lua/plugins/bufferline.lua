-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local bufferline = require("bufferline")
		bufferline.setup({
			options = {
				separator_style = "thick", -- 将分隔符样式更改为thick                                    │
				-- 过滤qf缓冲区
				custom_filter = function(buf, buf_nums)
					return vim.bo[buf].filetype ~= "qf"
				end,
				numbers = "ordinal", -- 显示id编号
				max_name_length = 10,
				max_prefix_length = 8, -- 当缓冲区被去重时使用的前缀
				tab_size = 10,
				-- 开启诊断提示
				diagnostics = "nvim_lsp", -- 诊断来源支持
				diagnostics_update_in_insert = false, -- 插入模式下开启诊断提示
				-- 诊断提示方式
				diagnostics_indicator = function(count, level)
					local icon = level:match("error") and " " or " "
					return "" .. icon .. count
				end,
				-- 侧边栏偏移设置
				offsets = {
					{
						filetype = "NvimTree",
						text = "File Explorer",
						text_align = "center",
						separator = true,
					},
					{
						filetype = "aerial",
						text = "Symbol Explorer",
						text_align = "center",
						separator = true,
					},
				},
				hover = {
					enabled = true, -- 鼠标悬停
					delay = 50, -- 悬停延迟时间（毫秒）
					reveal = { "close" }, -- 悬停时要显示的内容，可以是 'close'、'icon'、'number'、'name'
				},
			},
		})

		-- Go to nth buffer keymaps
		for n = 1, 9 do
			vim.keymap.set("n", "g" .. n, function()
				require("bufferline").go_to(n, true)
			end, { desc = "[Bufferline] Go to " .. n .. "th buffer" })
		end
		vim.keymap.set("n", "<leader>tp", "<cmd>BufferLineTogglePin<cr>", { desc = "图钉📌" })
		vim.keymap.set("n", "<leader>tg", ":BufferLinePick<CR>", { silent = true, noremap = true })
		vim.keymap.set("n", "<leader>tx", ":BufferLinePickClose<CR>", { silent = true, noremap = true })
		vim.keymap.set(
			"n",
			"<leader>td",
			"<cmd>BufferLineCloseOthers<cr>",
			{ desc = "删除当前buffer以外的所有buffers", silent = true }
		)
	end,
}
