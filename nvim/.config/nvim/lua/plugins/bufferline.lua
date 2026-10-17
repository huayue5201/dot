-- https://github.com/huayue5201/bufferline.nvim

return {
	dir = "~/neovim-plugins/bufferline.nvim",
	"akinsho/bufferline.nvim",
	-- 必须在首帧渲染前加载,否则会先画出内置 tabline 再被 bufferline 替换(启动闪烁)
	lazy = false,
	dependencies = {
		"nvim-tree/nvim-web-devicons",
		-- "Mirsmog/real-icons.nvim",
	},
	config = function()
		local bufferline = require("bufferline")

		-- bufferline 默认把分隔线画成 tabline 填充色(tint(normal_bg,-45)),
		-- 在非当前 tab 上几乎不可见,看起来只有当前 tab 有分隔。这里改用主题的
		-- gutter 色,让每个 tab 之间都有清晰的分隔线。
		-- 传函数而非颜色字符串:bufferline 在 ColorScheme 重新应用高亮时会重新求值,
		-- 分隔线颜色可跟随主题切换(修复上游 #1030)。
		local function sep_fg()
			local hl = vim.api.nvim_get_hl(0, { name = "LineNr" })
			if hl and hl.fg then
				return string.format("#%06x", hl.fg)
			end
			return "#4f5258"
		end

		-- 关闭按钮/右键：先判断是否被其他 tab 共享，共享则只移除不删除
		local function close_buffer(bufnr)
			require("core.tab_workspace").close_buffer(bufnr)
		end

		-- bufferline.setup(require("real-icons.integrations.bufferline").opts({
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
				separator_style = "slope",

				-- 指示器样式
				indicator = {
					-- icon = "▎", -- 指示器图标（underline 样式下不使用）
					style = "underline", -- icon, underline, none
				},

				-- ========== 名称设置 ==========
				-- 最大名称长度
				max_name_length = 20,

				-- 重复前缀最大长度
				max_prefix_length = 15,

				-- 是否截断名称
				truncate_names = true,

				-- 标签页大小（"auto" 自动按窗口宽度均分铺满）
				tab_size = "auto",

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
				right_mouse_command = close_buffer,

				-- 中键点击命令
				middle_mouse_command = nil,

				-- 关闭按钮命令（CloseOthers/CloseLeft/CloseRight/PickClose 也会走这里）
				close_command = close_buffer,

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
			highlights = {
				separator = { fg = sep_fg },
				separator_selected = { fg = sep_fg },
				separator_visible = { fg = sep_fg },
			},
		})

		-- ========== 按键映射（匹配你原有的 barbar 习惯）==========
		local map = vim.keymap.set
		local opts = { silent = true }

		-- 移动到上一个/下一个缓冲区
		map("n", "[b", "<Cmd>BufferLineCyclePrev<CR>", vim.tbl_extend("force", opts, { desc = "上一个缓冲区" }))
		map("n", "]b", "<Cmd>BufferLineCycleNext<CR>", vim.tbl_extend("force", opts, { desc = "下一个缓冲区" }))

		-- 移动缓冲区位置
		map(
			"n",
			"<leader>bP",
			"<Cmd>BufferLineMovePrev<CR>",
			vim.tbl_extend("force", opts, { desc = "向左移动缓冲区" })
		)
		map(
			"n",
			"<leader>bn",
			"<Cmd>BufferLineMoveNext<CR>",
			vim.tbl_extend("force", opts, { desc = "向右移动缓冲区" })
		)

		-- 跳转到指定序号的缓冲区（当前 tab 内可见序号；工作区隔离后只显示本 tab 的 buffer）
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
			"<leader>bp",
			"<Cmd>BufferLineTogglePin<CR>",
			vim.tbl_extend("force", opts, { desc = "固定/取消固定当前缓冲区" })
		)

		-- 关闭其他缓冲区
		map(
			"n",
			"<leader>bo",
			"<Cmd>BufferLineCloseOthers<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭除当前外所有缓冲区" })
		)

		-- 关闭左侧/右侧缓冲区
		map(
			"n",
			"<leader>bl",
			"<Cmd>BufferLineCloseLeft<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭左侧所有缓冲区" })
		)
		map(
			"n",
			"<leader>br",
			"<Cmd>BufferLineCloseRight<CR>",
			vim.tbl_extend("force", opts, { desc = "关闭右侧所有缓冲区" })
		)

		-- 缓冲区选择模式
		map(
			"n",
			"<leader>bb",
			"<Cmd>BufferLinePick<CR>",
			vim.tbl_extend("force", opts, { desc = "缓冲区选择模式" })
		)
		map(
			"n",
			"<leader>bc",
			"<Cmd>BufferLinePickClose<CR>",
			vim.tbl_extend("force", opts, { desc = "缓冲区选择删除模式" })
		)

		-- 排序命令
		map(
			"n",
			"<leader>bsn",
			"<Cmd>BufferLineSortByBufferNumber<CR>",
			vim.tbl_extend("force", opts, { desc = "按缓冲区编号排序" })
		)
		-- map("n", "gbbn", "<Cmd>BufferLineSortByName<CR>", vim.tbl_extend("force", opts, { desc = "按名称排序" }))
		map(
			"n",
			"<leader>bsd",
			"<Cmd>BufferLineSortByDirectory<CR>",
			vim.tbl_extend("force", opts, { desc = "按目录排序" })
		)
		map(
			"n",
			"<leader>bse",
			"<Cmd>BufferLineSortByExtension<CR>",
			vim.tbl_extend("force", opts, { desc = "按扩展名排序" })
		)

		-- tab_workspace 在 TabEnter 里改 buflisted，bufferline 没监听该事件；
		-- 延迟重绘，等 relist 全部完成后再按最终状态刷新（避免画到中间态）。
		vim.api.nvim_create_autocmd({ "TabEnter", "TabClosed", "BufAdd", "BufDelete" }, {
			group = vim.api.nvim_create_augroup("BufferlineWorkspaceRedraw", { clear = true }),
			callback = function()
				vim.schedule(function()
					vim.cmd("redrawtabline")
				end)
			end,
		})
	end,
}
