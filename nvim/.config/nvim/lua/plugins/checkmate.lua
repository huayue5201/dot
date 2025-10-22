-- https://github.com/bngarren/checkmate.nvim

return {
	"bngarren/checkmate.nvim",
	ft = "markdown", -- Lazy loads for Markdown files matching patterns in 'files'
	config = function()
		require("checkmate").setup({
			---@type checkmate.Config
			enabled = true, -- ✅ 是否启用 Checkmate 插件
			notify = true, -- ✅ 是否启用消息通知

			-- 默认文件匹配规则：
			--  - 匹配任何名为 todo 或 TODO 的文件（包括 .md 后缀）
			--  - 匹配任何 .todo 文件（可以是 ".todo" 或 ".todo.md"）
			-- 激活 Checkmate 的条件：文件名匹配 AND 文件类型为 markdown
			files = {
				"todo",
				"TODO",
				"todo.md",
				"TODO.md",
				"*.todo",
				"*.todo.md",
			},

			log = {
				level = "warn", -- ⚠️ 日志级别，可选 "debug"/"info"/"warn"/"error"
				use_file = true, -- ✅ 是否将日志写入文件
			},

			-- 默认快捷键映射
			keys = {
				["<cr>"] = {
					rhs = "<cmd>Checkmate toggle<CR>", -- 切换 TODO 状态（完成/未完成）
					desc = "Toggle todo item",
					modes = { "n", "v" }, -- 普通模式 + 可视模式
				},
				["<leader>Tc"] = {
					rhs = "<cmd>Checkmate check<CR>", -- 将 TODO 设置为完成
					desc = "Set todo item as checked (done)",
					modes = { "n", "v" },
				},
				["<leader>Tu"] = {
					rhs = "<cmd>Checkmate uncheck<CR>", -- 将 TODO 设置为未完成
					desc = "Set todo item as unchecked (not done)",
					modes = { "n", "v" },
				},
				["<leader>T="] = {
					rhs = "<cmd>Checkmate cycle_next<CR>", -- 循环切换到下一个状态
					desc = "Cycle todo item(s) to the next state",
					modes = { "n", "v" },
				},
				["<leader>T-"] = {
					rhs = "<cmd>Checkmate cycle_previous<CR>", -- 循环切换到上一个状态
					desc = "Cycle todo item(s) to the previous state",
					modes = { "n", "v" },
				},
				["<leader>Tn"] = {
					rhs = "<cmd>Checkmate create<CR>", -- 创建新 TODO
					desc = "Create todo item",
					modes = { "n", "v" },
				},
				["<leader>Tr"] = {
					rhs = "<cmd>Checkmate remove<CR>", -- 移除 TODO 标记（变为普通文本）
					desc = "Remove todo marker (convert to text)",
					modes = { "n", "v" },
				},
				["<leader>TR"] = {
					rhs = "<cmd>Checkmate remove_all_metadata<CR>", -- 移除 TODO 的所有元数据
					desc = "Remove all metadata from a todo item",
					modes = { "n", "v" },
				},
				["<leader>Ta"] = {
					rhs = "<cmd>Checkmate archive<CR>", -- 将已完成 TODO 归档到底部
					desc = "Archive checked/completed todo items (move to bottom section)",
					modes = { "n" },
				},
				["<leader>Tv"] = {
					rhs = "<cmd>Checkmate metadata select_value<CR>", -- 更新光标下元数据的值
					desc = "Update the value of a metadata tag under the cursor",
					modes = { "n" },
				},
				["<leader>T]"] = {
					rhs = "<cmd>Checkmate metadata jump_next<CR>", -- 跳到下一个元数据标签
					desc = "Move cursor to next metadata tag",
					modes = { "n" },
				},
				["<leader>T["] = {
					rhs = "<cmd>Checkmate metadata jump_previous<CR>", -- 跳到上一个元数据标签
					desc = "Move cursor to previous metadata tag",
					modes = { "n" },
				},
			},

			default_list_marker = "-", -- 默认 TODO 列表符号

			todo_states = { -- TODO 状态定义
				unchecked = { -- 未完成
					marker = "□", -- 状态标记符
					order = 1, -- 顺序，用于排序
				},
				checked = { -- 已完成
					marker = "✔",
					order = 2,
				},
			},

			style = {}, -- 自定义样式覆盖默认样式

			enter_insert_after_new = true, -- 创建新 TODO 后是否自动进入插入模式

			list_continuation = { -- 列表自动延续
				enabled = true,
				split_line = true,
				keys = {
					["<CR>"] = function() -- 回车创建新 TODO（不缩进）
						require("checkmate").create({ position = "below", indent = false })
					end,
					["<S-CR>"] = function() -- Shift+回车创建新 TODO（缩进）
						require("checkmate").create({ position = "below", indent = true })
					end,
				},
			},

			smart_toggle = { -- 智能切换 TODO 状态
				enabled = true,
				include_cycle = false,
				check_down = "direct_children", -- 向下直接子节点标记完成
				uncheck_down = "none", -- 向下不自动取消
				check_up = "direct_children", -- 向上直接父节点自动标记完成
				uncheck_up = "direct_children", -- 向上直接父节点取消完成
			},

			show_todo_count = true, -- 显示 TODO 数量
			todo_count_position = "eol", -- 在行尾显示 TODO 数量
			todo_count_recursive = true, -- 递归计算子节点 TODO 数量

			use_metadata_keymaps = true, -- 启用元数据快捷键

			metadata = { -- TODO 元数据配置示例
				priority = { -- 优先级标签
					style = function(context)
						local value = context.value:lower()
						if value == "high" then
							return { fg = "#ff5555", bold = true }
						elseif value == "medium" then
							return { fg = "#ffb86c" }
						else
							return { fg = "#8be9fd" }
						end
					end,
					get_value = function()
						return "medium"
					end, -- 默认值
					choices = function()
						return { "low", "medium", "high" }
					end,
					key = "<leader>Tp", -- 快捷键
					sort_order = 10, -- 排序优先级
					jump_to_on_insert = "value",
					select_on_insert = true,
				},

				started = { -- 开始时间标签
					aliases = { "init" },
					style = { fg = "#9fd6d5" },
					get_value = function()
						return tostring(os.date("%m/%d/%y %H:%M"))
					end,
					key = "<leader>Ts",
					sort_order = 20,
				},

				done = { -- 完成时间标签
					aliases = { "completed", "finished" },
					style = { fg = "#96de7a" },
					get_value = function()
						return tostring(os.date("%m/%d/%y %H:%M"))
					end,
					key = "<leader>Td",
					on_add = function(todo_item) -- 添加时自动标记为完成
						require("checkmate").set_todo_item(todo_item, "checked")
					end,
					on_remove = function(todo_item) -- 删除时自动标记为未完成
						require("checkmate").set_todo_item(todo_item, "unchecked")
					end,
					sort_order = 30,
				},
			},

			archive = { -- 归档设置
				heading = {
					title = "Archive", -- 归档标题
					level = 2, -- 标题等级（##）
				},
				parent_spacing = 0, -- 归档 TODO 间距
				newest_first = true, -- 新归档的 TODO 放在最前
			},

			linter = {
				enabled = true, -- 启用 TODO 检查（lint）
			},
		})
	end,
}
