-- https://github.com/nvim-neo-tree/neo-tree.nvim

return {
	"nvim-neo-tree/neo-tree.nvim", -- 插件 GitHub 仓库地址
	keys = {
		{ "<leader>ef", desc = "文件树" },
		{ "<leader>eb", desc = "buffers" },
		{ "<leader>eg", desc = "git diff" },
		{ "<leader>es", desc = "符号树" },
	},
	dependencies = {
		"nvim-lua/plenary.nvim",
		"nvim-tree/nvim-web-devicons", -- 不是必须的，但推荐安装
		"MunifTanjim/nui.nvim",
		-- "3rd/image.nvim", -- 可选的图片支持预览窗口：有关更多信息，请参见“# 预览模式”
	},
	config = function()
		-- 设置 Neo-tree 插件
		require("neo-tree").setup({
			close_if_last_window = true, -- 如果是标签页中的最后一个窗口，则关闭 Neo-tree
			sources = { -- Neo-tree 支持的源列表
				"filesystem",
				"buffers",
				"git_status",
				"document_symbols",
			},
			source_selector = { -- 源选择器的配置
				winbar = true, -- 在窗口工具栏上显示选择器
				statusline = false, -- 在状态栏上显示选择器
				show_scrolled_off_parent_node = false, -- 显示已滚动到父节点之外的节点
				sources = { -- 源列表
					{ source = "filesystem", display_name = " 󰉓 Files " },
					{ source = "buffers", display_name = " 󰈚 Buffers " },
					{ source = "git_status", display_name = " 󰊢 Git " },
					{ source = "document_symbols", display_name = " 󰆧 Symbols " },
				},
				content_layout = "start", -- 内容布局
				tabs_layout = "equal", -- 标签布局
				truncation_character = "…", -- 截断字符
				tabs_min_width = nil, -- 标签最小宽度
				tabs_max_width = nil, -- 标签最大宽度
				padding = 0, -- 边距
				separator = { left = "▏", right = "▕" }, -- 分隔符
				separator_active = nil, -- 活动分隔符
				show_separator_on_edge = false, -- 在边缘显示分隔符
				highlight_tab = "NeoTreeTabInactive", -- 高亮标签
				highlight_tab_active = "NeoTreeTabActive", -- 活动标签高亮
				highlight_background = "NeoTreeTabInactive", -- 背景高亮
				highlight_separator = "NeoTreeTabSeparatorInactive", -- 分隔符高亮
				highlight_separator_active = "NeoTreeTabSeparatorActive", -- 活动分隔符高亮
			},
			event_handlers = { -- 事件处理程序
				{
					event = "file_opened", -- 文件打开事件
					handler = function(file_path) -- 处理函数
						-- 自动关闭 Neo-tree
						require("neo-tree.command").execute({ action = "close" })
					end,
				},
			},
			window = { -- 窗口设置
				position = "left", -- 窗口位置
				width = 35, -- 窗口宽度
				mappings = { -- 键盘映射
					["P"] = { "toggle_preview", config = { use_float = false, use_image_nvim = true } },
					["<space>"] = { "toggle_node", nowait = true },
					["H"] = "set_root",
					["."] = "toggle_hidden",
					["e"] = function()
						vim.api.nvim_exec("Neotree focus filesystem left", true)
					end,
					["b"] = function()
						vim.api.nvim_exec("Neotree focus buffers left", true)
					end,
					["g"] = function()
						vim.api.nvim_exec("Neotree focus git_status left", true)
					end,
					["s"] = function()
						vim.api.nvim_exec("Neotree focus document_symbols left", true)
					end,
				},
			},
		})
		-- 设置快捷键
		vim.keymap.set("n", "<space>ef", "<cmd>Neotree toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>eb", "<cmd>Neotree buffers toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>eg", "<cmd>Neotree git_status toggle<cr>", { silent = true, noremap = true })
		vim.keymap.set("n", "<space>es", "<cmd>Neotree document_symbols toggle<cr>", { silent = true, noremap = true })
	end,
}
