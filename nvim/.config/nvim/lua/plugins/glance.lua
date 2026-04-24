-- https://github.com/DNLHC/glance.nvim

return {
	"dnlhc/glance.nvim",
	event = "VeryLazy",
	cmd = "Glance",
	config = function()
		-- Lua configuration
		local glance = require("glance")
		local actions = glance.actions

		glance.setup({
			height = 18, -- 窗口高度
			zindex = 45,

			-- 启用后，会在预览窗口后面添加虚拟行，以在父窗口中保持上下文
			-- 需要 Neovim >= 0.10.0
			preserve_win_context = true,

			-- 控制预览窗口是“嵌入”在父窗口中，还是浮动在所有窗口之上
			detached = function(winid)
				-- 当父窗口宽度 < 100 列时自动切换为浮动模式
				return vim.api.nvim_win_get_width(winid) < 100
			end,
			-- 或者使用固定设置：detached = true,

			preview_win_opts = { -- 配置预览窗口选项
				cursorline = true,
				number = true,
				wrap = true,
			},

			border = {
				enable = false, -- 显示窗口边框。仅支持水平边框
				top_char = "―",
				bottom_char = "―",
			},

			list = {
				position = "right", -- 列表窗口位置：'left' 或 'right'
				width = 0.33, -- 宽度百分比（0.1 到 0.5）
			},

			theme = {
				enable = true, -- 根据当前 colorscheme 自动生成颜色
				mode = "auto", -- 'brighten' | 'darken' | 'auto'，auto 会根据主题亮度自动选择
			},

			mappings = {
				list = {
					["j"] = actions.next, -- 下一个条目
					["k"] = actions.previous, -- 上一个条目
					["<Down>"] = actions.next,
					["<Up>"] = actions.previous,
					["<Tab>"] = actions.next_location, -- 下一个位置（跳过分组，循环）
					["<S-Tab>"] = actions.previous_location, -- 上一个位置（跳过分组，循环）
					["<C-u>"] = actions.preview_scroll_win(5), -- 预览窗口向上滚动
					["<C-d>"] = actions.preview_scroll_win(-5), -- 预览窗口向下滚动
					["v"] = actions.jump_vsplit, -- 在垂直分屏中打开
					["s"] = actions.jump_split, -- 在水平分屏中打开
					["t"] = actions.jump_tab, -- 在新标签页中打开
					["<CR>"] = actions.jump, -- 跳转到位置
					["o"] = actions.jump,
					["l"] = actions.open_fold,
					["h"] = actions.close_fold,
					["<leader>l"] = actions.enter_win("preview"), -- 聚焦预览窗口
					["q"] = actions.close, -- 关闭 Glance 窗口
					["Q"] = actions.close,
					["<Esc>"] = actions.close,
					["<C-q>"] = actions.quickfix, -- 将所有位置发送到 quickfix 列表
					-- ['<Esc>'] = false -- 禁用某个映射
				},

				preview = {
					["Q"] = actions.close,
					["<Tab>"] = actions.next_location, -- 下一个位置（跳过分组，循环）
					["<S-Tab>"] = actions.previous_location, -- 上一个位置（跳过分组，循环）
					["<leader>l"] = actions.enter_win("list"), -- 聚焦列表窗口
				},
			},

			hooks = {}, -- 详见 Hooks 部分

			folds = {
				fold_closed = "",
				fold_open = "",
				folded = true, -- 启动时自动折叠列表
			},

			indent_lines = {
				enable = true, -- 显示缩进线
				icon = "│",
			},

			winbar = {
				enable = true, -- 为预览窗口启用 winbar（需要 Neovim 0.8+）
			},

			use_trouble_qf = false, -- 使用 trouble.nvim 打开 quickfix，而不是内置 quickfix
		})

		vim.keymap.set("n", "grD", "<CMD>Glance definitions<CR>", {
			desc = "Glance: Show definitions",
		})

		vim.keymap.set("n", "grR", "<CMD>Glance references<CR>", {
			desc = "Glance: Show references",
		})

		vim.keymap.set("n", "grY", "<CMD>Glance type_definitions<CR>", {
			desc = "Glance: Show type definitions",
		})

		vim.keymap.set("n", "grM", "<CMD>Glance implementations<CR>", {
			desc = "Glance: Show implementations",
		})
	end,
}
