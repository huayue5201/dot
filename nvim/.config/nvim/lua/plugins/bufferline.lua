-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "UIEnter",
	dependencies = "nvim-tree/nvim-web-devicons",
	config = function()
		local icons = require("lsp.lsp_utils").icons.diagnostic

		require("bufferline").setup({
			options = {
				separator_style = "thin",
				custom_filter = function(buf) -- 过滤qf缓冲区
					local excluded_filetypes = { "qf", "help", "fugitive" }
					local excluded_buftypes = { "acwrite", "nofile" }
					local filetype = vim.bo[buf].filetype
					local buftype = vim.bo[buf].buftype
					return not vim.tbl_contains(excluded_filetypes, filetype)
						and not vim.tbl_contains(excluded_buftypes, buftype)
				end,
				-- numbers = "ordinal", -- 显示buffer的编号
				numbers = function(opts)
					return string.format("%s·%s", opts.raise(opts.id), opts.lower(opts.ordinal))
				end,
				max_name_length = 10, -- buffer名称的最大长度
				max_prefix_length = 8, -- 去重时的前缀长度
				tab_size = 10, -- tab的大小
				diagnostics = "nvim_lsp", -- 开启诊断提示，来源为nvim_lsp
				diagnostics_indicator = function(count, level) -- 诊断提示的图标和数量显示
					local icon = level:match("error") and icons.ERROR or icons.WARN
					return "" .. icon .. count
				end,
				toggle_hidden_on_enter = true, -- 重新进入隐藏的组时，自动展开
				-- items = {},
				offsets = { -- 侧边栏偏移设置
					{
						filetype = "trouble",
						text = " Trouble",
						highlight = { sep = { link = "WinSeparator" } },
						separator = "┃",
					},
					{
						filetype = "neo-tree",
						text = "󰪶 File Explorer",
						raw = " %{%v:lua.__get_selector()%} ",
						highlight = { sep = { link = "WinSeparator" } },
						separator = "┃",
					},
				},
				hover = { -- 鼠标悬停设置
					enabled = true, -- 开启鼠标悬停
					delay = 50, -- 悬停延迟时间
					reveal = { "close" }, -- 悬停时显示的内容
				},
			},
		})

		-- Jump to visible buffers
		for i = 1, 9 do
			vim.keymap.set(
				"n",
				"<leader>b" .. i,
				"<Cmd>BufferLineGoToBuffer " .. i .. "<CR>",
				{ silent = true, desc = "BufferLine: go to buffer " .. i }
			)
		end

		vim.keymap.set("n", "<leader>bp", "<cmd>BufferLineTogglePin<cr>", {
			desc = "BufferLine: toggle pin",
		})

		vim.keymap.set("n", "<leader>bs", "<cmd>BufferLinePick<CR>", {
			desc = "BufferLine: pick buffer",
		})

		-- vim.keymap.set("n", "<leader>rb", "<cmd>BufferLinePickClose<CR>", {
		-- 	desc = "BufferLine: pick & close buffer",
		-- })

		vim.keymap.set("n", "<leader>rab", "<cmd>BufferLineCloseOthers<cr>", {
			desc = "BufferLine: close other buffers",
		})
	end,
}
