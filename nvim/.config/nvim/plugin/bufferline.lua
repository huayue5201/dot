-- https://github.com/akinsho/bufferline.nvim

vim.g.now(function()
	vim.g.add({
		source = "akinsho/bufferline.nvim",
	})

	_G.__cached_neo_tree_selector = nil
	_G.__get_selector = function()
		return _G.__cached_neo_tree_selector
	end

	require("bufferline").setup({
		options = {
			separator_style = "thick", -- 分隔符样式设置为thick
			custom_filter = function(buf) -- 过滤qf缓冲区
				return vim.bo[buf].filetype ~= "qf"
			end,
			numbers = "ordinal", -- 显示buffer的编号
			max_name_length = 10, -- buffer名称的最大长度
			max_prefix_length = 8, -- 去重时的前缀长度
			tab_size = 10, -- tab的大小
			diagnostics = "nvim_lsp", -- 开启诊断提示，来源为nvim_lsp
			diagnostics_indicator = function(count, level) -- 诊断提示的图标和数量显示
				local icon = level:match("error") and "✘ " or " "
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
					raw = " %{%v:lua.__get_selector()%} ",
					highlight = { sep = { link = "WinSeparator" } },
					separator = "┃",
				},
				-- {
				-- 	filetype = "neo-tree",
				-- 	text = "File Explorer",
				-- 	text_align = "center",
				-- 	separator = true,
				-- },
				{
					filetype = "aerial",
					text = "Symbol Explorer",
					text_align = "center",
					separator = true,
				},
			},
			hover = { -- 鼠标悬停设置
				enabled = true, -- 开启鼠标悬停
				delay = 50, -- 悬停延迟时间
				reveal = { "close" }, -- 悬停时显示的内容
			},
		},
	})

	-- 快捷键设置
	for n = 1, 9 do
		vim.keymap.set("n", "g" .. n, function() -- 跳转到第n个buffer
			require("bufferline").go_to(n, true)
		end, { desc = "[Bufferline] 跳转到第" .. n .. "个buffer" })
	end

	vim.keymap.set("n", "<leader>tp", "<cmd>BufferLineTogglePin<cr>", { desc = "图钉📌" })
	vim.keymap.set("n", "<leader>tb", ":BufferLinePick<CR>", { desc = "跳转到任意可见标签" })
	vim.keymap.set("n", "<leader>tx", ":BufferLinePickClose<CR>", { desc = "删除任意可见标签" })
	vim.keymap.set("n", "<leader>td", "<cmd>BufferLineCloseOthers<cr>", { desc = "删除其他所有buffers" })
end)
