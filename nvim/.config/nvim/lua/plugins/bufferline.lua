-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "VeryLazy",
	dependencies = "echasnovski/mini.icons",
	config = function()
		_G.__cached_neo_tree_selector = nil
		_G.__get_selector = function()
			return _G.__cached_neo_tree_selector
		end

		local icons = require("autoload.utils").icons.diagnostic
		require("bufferline").setup({
			options = {
				separator_style = "thick", -- 分隔符样式设置为thick
				custom_filter = function(buf) -- 过滤qf缓冲区
					local excluded_filetypes = { "qf", "help", "terminal", "fugitive" }
					local excluded_buftypes = { "terminal", "acwrite" }
					local filetype = vim.bo[buf].filetype
					local buftype = vim.bo[buf].buftype
					return not vim.tbl_contains(excluded_filetypes, filetype)
						and not vim.tbl_contains(excluded_buftypes, buftype)
				end,
				numbers = "ordinal", -- 显示buffer的编号
				max_name_length = 10, -- buffer名称的最大长度
				max_prefix_length = 8, -- 去重时的前缀长度
				tab_size = 10, -- tab的大小
				diagnostics = "nvim_lsp", -- 开启诊断提示，来源为nvim_lsp
				diagnostics_indicator = function(count, level) -- 诊断提示的图标和数量显示
					local icon = level:match("error") and icons.ERROR or icons.WARN
					return "" .. icon .. count
				end,
				toggle_hidden_on_enter = true, -- 重新进入隐藏的组时，自动展开
				items = {
					{
						name = "Tests", -- 组名
						highlight = { underline = true, sp = "blue" }, -- 高亮样式
						priority = 2, -- 显示优先级
						icon = "", -- 组的图标
						matcher = function(buf) -- 匹配测试文件的函数
							return buf.filename:match("%_test") or buf.filename:match("%_spec")
						end,
					},
					{
						name = "Docs", -- 组名
						highlight = { undercurl = true, sp = "green" }, -- 高亮样式
						auto_close = false, -- 当前buffer不在组内时不自动关闭
						matcher = function(buf) -- 匹配文档文件的函数
							return buf.filename:match("%.md") or buf.filename:match("%.txt")
						end,
						separator = { -- 分隔符设置
							style = require("bufferline.groups").separator.tab,
						},
					},
				},
				offsets = { -- 侧边栏偏移设置
					{
						filetype = "neo-tree",
						text = "File explorer",
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

		vim.keymap.set("n", "<leader>tp", "<cmd>BufferLineTogglePin<cr>", { desc = "图钉📌" })
		vim.keymap.set("n", "<leader>gb", ":BufferLinePick<CR>", { desc = "跳转到任意可见标签" })
		vim.keymap.set("n", "<leader>tx", ":BufferLinePickClose<CR>", { desc = "删除任意可见标签" })
		vim.keymap.set("n", "<leader>td", "<cmd>BufferLineCloseOthers<cr>", { desc = "删除其他所有buffers" })
	end,
}
