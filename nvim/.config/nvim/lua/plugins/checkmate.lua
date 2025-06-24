-- https://github.com/bngarren/checkmate.nvim

return {
	"bngarren/checkmate.nvim",
	ft = "markdown", -- Lazy loads for Markdown files matching patterns in 'files'
	config = function()
		require("checkmate").setup({
			enabled = true,
			notify = true,
			-- Default file matching:
			--  - Any `todo` or `TODO` file, including with `.md` extension
			--  - Any `.todo` extension (can be ".todo" or ".todo.md")
			-- To activate Checkmate, the filename must match AND the filetype must be "markdown"
			files = {
				"todo",
				"TODO",
				"todo.md",
				"TODO.md",
				"*.todo",
				"*.todo.md",
			},
			log = {
				level = "info",
				use_file = false,
				use_buffer = false,
			},
			keys = {
				["<cr>"] = {
					rhs = "<cmd>Checkmate toggle<CR>",
					desc = "切换任务项状态",
					modes = { "n", "v" },
				},
				["<leader>tdn"] = {
					rhs = "<cmd>Checkmate create<CR>",
					desc = "创建新的任务项",
					modes = { "n", "v" },
				},
				["<leader>tdR"] = {
					rhs = "<cmd>Checkmate remove_all_metadata<CR>",
					desc = "移除任务项的所有元数据",
					modes = { "n", "v" },
				},
				["<leader>tda"] = {
					rhs = "<cmd>Checkmate archive<CR>",
					desc = "归档已完成的任务项 (移动到底部)",
					modes = { "n" },
				},
				["<leader>tdv"] = {
					rhs = "<cmd>Checkmate metadata select_value<CR>",
					desc = "更新光标下的元数据标签的值",
					modes = { "n" },
				},
				["<leader>t]"] = {
					rhs = "<cmd>Checkmate metadata jump_next<CR>",
					desc = "跳转到下一个元数据标签",
					modes = { "n" },
				},
				["<leader>t["] = {
					rhs = "<cmd>Checkmate metadata jump_previous<CR>",
					desc = "跳转到上一个元数据标签",
					modes = { "n" },
				},
			},
			default_list_marker = "-",
			todo_markers = {
				unchecked = "□",
				checked = "✔",
			},
			style = {}, -- override defaults
			todo_action_depth = 1, --  Depth within a todo item's hierachy from which actions (e.g. toggle) will act on the parent todo item
			enter_insert_after_new = true, -- Should enter INSERT mode after :CheckmateCreate (new todo)
			smart_toggle = {
				enabled = true,
				check_down = "direct_children",
				uncheck_down = "none",
				check_up = "direct_children",
				uncheck_up = "direct_children",
			},
			show_todo_count = true,
			todo_count_position = "eol",
			todo_count_recursive = true,
			use_metadata_keymaps = true,
			metadata = {
				-- Example: A @priority tag that has dynamic color based on the priority value
				priority = {
					style = function(context)
						local value = context.value:lower()
						if value == "high" then
							return { fg = "#ff5555", bold = true }
						elseif value == "medium" then
							return { fg = "#ffb86c" }
						elseif value == "low" then
							return { fg = "#8be9fd" }
						else -- fallback
							return { fg = "#8be9fd" }
						end
					end,
					get_value = function()
						return "medium" -- Default priority
					end,
					choices = function()
						return { "low", "medium", "high" }
					end,
					key = "<leader>Tp",
					sort_order = 10,
					jump_to_on_insert = "value",
					select_on_insert = true,
				},
				-- Example: A @started tag that uses a default date/time string when added
				started = {
					aliases = { "init" },
					style = { fg = "#9fd6d5" },
					get_value = function()
						return tostring(os.date("%m/%d/%y %H:%M"))
					end,
					key = "<leader>Ts",
					sort_order = 20,
				},
				-- Example: A @done tag that also sets the todo item state when it is added and removed
				done = {
					aliases = { "completed", "finished" },
					style = { fg = "#96de7a" },
					get_value = function()
						return tostring(os.date("%m/%d/%y %H:%M"))
					end,
					key = "<leader>Td",
					on_add = function(todo_item)
						require("checkmate").set_todo_item(todo_item, "checked")
					end,
					on_remove = function(todo_item)
						require("checkmate").set_todo_item(todo_item, "unchecked")
					end,
					sort_order = 30,
				},
			},
			archive = {
				heading = {
					title = "Archive",
					level = 2, -- e.g. ##
				},
				parent_spacing = 0, -- no extra lines between archived todos
				newest_first = true,
			},
			linter = {
				enabled = true,
			},
		})
	end,
}
