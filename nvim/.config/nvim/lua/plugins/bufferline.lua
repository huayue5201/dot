-- https://github.com/akinsho/bufferline.nvim

return {
	"akinsho/bufferline.nvim",
	event = "UIEnter",
	dependencies = {
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		local bufferline = require("bufferline")

		bufferline.setup({
			options = {
				-- ========== 基础设置 ==========
				-- 模式：buffers（显示缓冲区）或 tabs（显示标签页）
				mode = "buffers",

				-- 样式预设：default, minimal, no_italic, no_bold
				style_preset = bufferline.style_preset.default,

				-- 是否允许主题覆盖高亮组
				themable = true,

				-- 是否始终显示缓冲区栏
				always_show_bufferline = true,

				-- 当只有一个缓冲区时自动隐藏
				auto_toggle_bufferline = false,

				-- ========== 编号显示 ==========
				-- 编号显示方式：none, ordinal, buffer_id, both, 或自定义函数
				numbers = "both",

				-- ========== 图标设置 ==========
				-- 是否显示缓冲区图标
				show_buffer_icons = true,

				-- 是否显示关闭图标
				show_close_icon = true,

				-- 是否显示缓冲区关闭按钮
				show_buffer_close_icons = true,

				-- 是否显示标签页指示器
				show_tab_indicators = true,

				-- 是否启用彩色图标
				color_icons = true,

				-- ========== 图标样式 ==========
				buffer_close_icon = " ", -- 关闭按钮图标
				modified_icon = "●", -- 修改标记图标
				close_icon = "", -- 关闭图标
				left_trunc_marker = "", -- 左侧截断标记
				right_trunc_marker = "", -- 右侧截断标记

				-- ========== 分隔符样式 ==========
				-- 可选：slant, slope, thick, thin, 或自定义 {"left", "right"}
				separator_style = "thin",

				-- 指示器样式
				indicator = {
					icon = "▎", -- 指示器图标
					style = "icon", -- icon, underline, none
				},

				-- ========== 名称设置 ==========
				-- 最大名称长度
				max_name_length = 20,

				-- 重复前缀最大长度
				max_prefix_length = 15,

				-- 是否截断名称
				truncate_names = true,

				-- 标签页大小
				tab_size = 18,

				-- 是否显示重复前缀
				show_duplicate_prefix = true,

				-- 跨组是否视为重复
				duplicates_across_groups = true,

				-- ========== 诊断设置 ==========
				-- 诊断来源：false, "nvim_lsp", "coc"
				diagnostics = "nvim_lsp",

				-- 插入模式下是否更新诊断
				diagnostics_update_in_insert = false,

				-- 是否使用事件更新诊断
				diagnostics_update_on_event = true,

				-- 诊断指示器显示函数
				diagnostics_indicator = function(count, level, diagnostics_dict, context)
					-- 只在非当前缓冲区显示
					if context.buffer:current() then
						return ""
					end
					local icon = level:match("error") and " " or " "
					return icon .. count
				end,

				-- ========== 鼠标操作 ==========
				-- 左键点击命令（%d 会被缓冲区编号替换）
				left_mouse_command = "buffer %d",

				-- 右键点击命令
				right_mouse_command = "bdelete! %d",

				-- 中键点击命令
				middle_mouse_command = nil,

				-- 关闭按钮命令
				close_command = "bdelete! %d",

				-- ========== 悬停设置（需要 Neovim 0.8+）==========
				hover = {
					enabled = true, -- 启用悬停效果
					delay = 200, -- 悬停延迟（毫秒）
					reveal = { "close" }, -- 悬停时显示的元素
				},

				-- ========== 排序设置 ==========
				-- 排序方式：insert_after_current, insert_at_end, id, extension,
				--          relative_directory, directory, tabs, 或自定义函数
				sort_by = "insert_after_current",

				-- 是否持久化缓冲区排序
				persist_buffer_sort = true,

				-- 移动时是否在两端环绕
				move_wraps_at_ends = true,

				-- ========== 其他设置 ==========
				-- 是否强制统一标签页大小
				enforce_regular_tabs = true,

				-- 自定义过滤器函数
				custom_filter = function(buf_number, buf_numbers)
					-- 过滤 help 缓冲区
					if vim.bo[buf_number].filetype == "help" then
						return false
					end
					-- 过滤 quickfix 缓冲区
					if vim.bo[buf_number].filetype == "qf" then
						return false
					end
					return true
				end,

				-- 名称格式化函数
				name_formatter = function(buf)
					-- buf 包含：name, path, bufnr, buffers(tabs only), tabnr(tabs only)
					return buf.name
				end,

				-- 自定义获取图标函数
				get_element_icon = nil,

				-- ========== 侧边栏偏移 ==========
				offsets = {
					{
						filetype = "neo-tree",
						text = "File Explorer", -- 显示文本
						text_align = "center",
						separator = true,
						highlight = "Directory",
					},
				},

				-- ========== 选择模式设置 ==========
				pick = {
					-- 选择字符集
					alphabet = "asdfjkl;ghnmxcvbziowerutyqpASDFJKLGHNMXCVBZIOWERUTYQP",
				},

				-- ========== 分组设置 ==========
				groups = {
					options = {
						-- 进入时是否自动打开隐藏的分组
						toggle_hidden_on_enter = true,
					},
					items = {
						-- 固定缓冲区分组（内置）
						require("bufferline.groups").builtin.pinned:with({
							icon = " ",
						}),
						-- 未分组缓冲区（内置）
						require("bufferline.groups").builtin.ungrouped,
						-- 自定义分组示例（按需取消注释）
						-- {
						--     name = "Tests",
						--     icon = " ",
						--     priority = 2,
						--     matcher = function(buf)
						--         return buf.filename:match("%_test") or buf.filename:match("%_spec")
						--     end,
						-- },
					},
				},

				-- ========== 自定义区域 ==========
				-- 在缓冲区栏右侧添加自定义内容
				custom_areas = {
					-- 右侧区域示例（显示 LSP 诊断统计）
					-- right = function()
					--     local result = {}
					--     local seve = vim.diagnostic.severity
					--     local errors = #vim.diagnostic.get(0, { severity = seve.ERROR })
					--     local warnings = #vim.diagnostic.get(0, { severity = seve.WARN })
					--
					--     if errors > 0 then
					--         table.insert(result, { text = "  " .. errors, link = "DiagnosticError" })
					--     end
					--     if warnings > 0 then
					--         table.insert(result, { text = "  " .. warnings, link = "DiagnosticWarn" })
					--     end
					--     return result
					-- end,
				},
			},

			-- ========== 高亮自定义 ==========
			highlights = {
				-- 填充区域
				fill = {
					fg = "#5c6370",
					bg = "#1e1e2e",
				},
				-- 背景
				background = {
					fg = "#5c6370",
					bg = "#1e1e2e",
				},
				-- 选中的缓冲区
				buffer_selected = {
					fg = "#ffffff",
					bg = "#2c2e3e",
					bold = true,
					italic = false,
				},
				-- 可见的缓冲区
				buffer_visible = {
					fg = "#5c6370",
					bg = "#1e1e2e",
				},
				-- 关闭按钮
				close_button = {
					fg = "#5c6370",
					bg = "#1e1e2e",
				},
				close_button_selected = {
					fg = "#ff6b6b",
					bg = "#2c2e3e",
				},
				-- 分隔符
				separator = {
					fg = "#3b3b5c",
					bg = "#1e1e2e",
				},
				separator_selected = {
					fg = "#3b3b5c",
					bg = "#2c2e3e",
				},
				-- 指示器
				indicator_selected = {
					fg = "#89b4fa",
					bg = "#2c2e3e",
				},
				-- 修改标记
				modified = {
					fg = "#f9e2af",
					bg = "#1e1e2e",
				},
				modified_selected = {
					fg = "#f9e2af",
					bg = "#2c2e3e",
				},
				-- 诊断高亮
				error = { fg = "#f38ba8", bg = "#1e1e2e" },
				error_selected = { fg = "#f38ba8", bg = "#2c2e3e" },
				warning = { fg = "#fab387", bg = "#1e1e2e" },
				warning_selected = { fg = "#fab387", bg = "#2c2e3e" },
				hint = { fg = "#94e2d5", bg = "#1e1e2e" },
				hint_selected = { fg = "#94e2d5", bg = "#2c2e3e" },
				info = { fg = "#89b4fa", bg = "#1e1e2e" },
				info_selected = { fg = "#89b4fa", bg = "#2c2e3e" },
			},
		})

		-- ========== 按键映射（匹配你原有的 barbar 习惯）==========
		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		-- 移动到上一个/下一个缓冲区
		map("n", "[b", "<Cmd>BufferLineCyclePrev<CR>", vim.tbl_extend("force", opts, { desc = "上一个缓冲区" }))
		map("n", "]b", "<Cmd>BufferLineCycleNext<CR>", vim.tbl_extend("force", opts, { desc = "下一个缓冲区" }))

		-- 移动缓冲区位置
		map(
			"n",
			"gbp",
			"<Cmd>BufferLineMovePrev<CR>",
			vim.tbl_extend("force", opts, { desc = "向左移动缓冲区" })
		)
		map(
			"n",
			"gbn",
			"<Cmd>BufferLineMoveNext<CR>",
			vim.tbl_extend("force", opts, { desc = "向右移动缓冲区" })
		)

		-- 跳转到指定位置的缓冲区（可见位置）
		for i = 1, 9 do
			map(
				"n",
				"g" .. i,
				"<Cmd>BufferLineGoToBuffer " .. i .. "<CR>",
				vim.tbl_extend("force", opts, { desc = "跳转到缓冲区 " .. i })
			)
		end

		-- 固定/取消固定
		map(
			"n",
			"gbp",
			"<Cmd>BufferLineTogglePin<CR>",
			vim.tbl_extend("force", opts, { desc = "固定/取消固定当前缓冲区" })
		)

		-- 关闭缓冲区
		map("n", "<c-esc>", "<Cmd>bd<CR>", vim.tbl_extend("force", opts, { desc = "关闭当前缓冲区" }))

		-- 关闭其他缓冲区
		map(
			"n",
			"<leader>cab",
			"<Cmd>BufferLineCloseOthers<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭除当前外所有缓冲区" })
		)

		-- 关闭左侧/右侧缓冲区
		map(
			"n",
			"<leader>cbl",
			"<Cmd>BufferLineCloseLeft<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭左侧所有缓冲区" })
		)
		map(
			"n",
			"<leader>cbr",
			"<Cmd>BufferLineCloseRight<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭右侧所有缓冲区" })
		)

		-- 缓冲区选择模式
		map("n", "<leader>sb", "<Cmd>BufferLinePick<CR>", vim.tbl_extend("force", opts, { desc = "缓冲区选择模式" }))
		map(
			"n",
			"<leader>csb",
			"<Cmd>BufferLinePickClose<CR>",
			vim.tbl_extend("force", opts, { desc = "缓冲区选择删除模式" })
		)

		-- 排序命令
		map(
			"n",
			"gbsn",
			"<Cmd>BufferLineSortByBufferNumber<CR>",
			vim.tbl_extend("force", opts, { desc = "按缓冲区编号排序" })
		)
		map("n", "gbbn", "<Cmd>BufferLineSortByName<CR>", vim.tbl_extend("force", opts, { desc = "按名称排序" }))
		map(
			"n",
			"gbsd",
			"<Cmd>BufferLineSortByDirectory<CR>",
			vim.tbl_extend("force", opts, { desc = "按目录排序" })
		)
		map(
			"n",
			"gbse",
			"<Cmd>BufferLineSortByExtension<CR>",
			vim.tbl_extend("force", opts, { desc = "按扩展名排序" })
		)
	end,
}
