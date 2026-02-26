---@diagnostic disable: missing-fields
-- https://github.com/igorlfs/nvim-dap-view

return {
	"igorlfs/nvim-dap-view",
	lazy = true,
	-- event = "VeryLazy",
	---@module 'dap-view'
	---@type dapview.Config
	config = function()
		require("dap-view").setup({
			-----------------------------------------------------------
			-- 窗口顶栏配置
			-----------------------------------------------------------
			winbar = {
				show = true, -- 是否显示顶栏

				-- 显示的视图部分列表
				-- 可以添加 "console" 来将终端与其他视图合并
				sections = {
					"watches",
					"scopes",
					"exceptions",
					"breakpoints",
					"threads",
					"disassembly",
					"repl",
					-- "console",
				},

				-- 默认显示的视图部分（必须是上面列表中的一项）
				default_section = "watches",

				-- 在标签中显示快捷键提示
				show_keymap_hints = false,

				-- 基础视图部分的详细配置
				-- base_sections = {
				-- 	breakpoints = { label = "Breakpoints", keymap = "B" }, -- 断点视图
				-- 	scopes = { label = "Scopes", keymap = "S" }, -- 变量作用域视图
				-- 	exceptions = { label = "Exceptions", keymap = "E" }, -- 异常视图
				-- 	watches = { label = "Watches", keymap = "W" }, -- 监视变量视图
				-- 	threads = { label = "Threads", keymap = "T" }, -- 线程视图
				-- 	repl = { label = "REPL", keymap = "R" }, -- 交互式命令行视图
				-- 	sessions = { label = "Sessions", keymap = "K" }, -- 调试会话视图
				-- 	console = { label = "Console", keymap = "C" }, -- 控制台视图
				-- },

				-- 自定义视图部分（可以添加自己的视图）
				-- custom_sections = {},

				-----------------------------------------------------------
				-- 调试控制按钮配置
				-----------------------------------------------------------
				controls = {
					enabled = true, -- 是否启用控制按钮
					position = "right", -- 按钮位置（左/右）
				},
			},

			-----------------------------------------------------------
			-- 窗口布局配置
			-----------------------------------------------------------
			windows = {
				size = 0.28, -- 稍微增大一点总高度到 28%
				position = "below",
				terminal = {
					size = 0.25, -- 终端占 dap-view 的 25%（例如用于显示程序输出）
					position = "right", -- ⭐ 关键修改：将终端放在底部
					hide = { "delve" }, -- 如果你调试 Go，可以隐藏终端
				},
			},

			-----------------------------------------------------------
			-- 跳转行为配置
			-----------------------------------------------------------
			-- 控制选择断点或导航堆栈时的跳转方式
			-- 类似于内置的 'switchbuf' 选项，参见 :help 'switchbuf'
			-- 支持的选项：newtab, useopen, usetab, uselast
			switchbuf = "usetab,uselast", -- 优先使用已有标签页和上次使用的窗口

			-----------------------------------------------------------
			-- 自动开关行为配置
			-----------------------------------------------------------
			-- 自动打开/关闭 dapview 窗口
			-- 可选值：
			-- - false: 不自动切换
			-- - true: 会话开始时自动打开，结束时自动关闭
			-- - "keep_terminal": 同上，但会话结束后保留终端窗口
			-- - "open_term": 只在新会话时打开终端，不做其他操作
			auto_toggle = true,

			-----------------------------------------------------------
			-- 标签页跟随行为配置
			-----------------------------------------------------------
			-- 切换标签页时是否重新打开 dapview 窗口
			-- 可以是布尔值，也可以是一个函数动态决定
			-- 如果是函数，接收当前会话的适配器名称作为参数
			follow_tab = false,
		})

		-- 切换 DAP 视图显示/隐藏
		vim.keymap.set("n", "<leader>dt", function()
			require("dap-view").toggle()
		end, { desc = "DAP: 切换调试视图" })

		-- 智能添加监视表达式：
		-- DapViewWatch
		-- - 如果有选中文本，使用选中的文本
		-- - 否则使用当前光标下的单词
		-- - 如果没有，则弹出输入框
		vim.keymap.set({ "n", "v" }, "<leader>dw", function()
			local expr = nil
			local mode = vim.api.nvim_get_mode().mode

			if mode:match("^v") then -- 可视模式
				-- 获取选中的文本
				local start_pos = vim.fn.getpos("'<")
				local end_pos = vim.fn.getpos("'>")
				local lines = vim.fn.getline(start_pos[2], end_pos[2])

				if #lines == 1 then
					expr = string.sub(lines[1], start_pos[3], end_pos[3])
				else
					-- 对于跨行的选择，简单拼接
					local first_line = string.sub(lines[1], start_pos[3])
					local last_line = string.sub(lines[#lines], 1, end_pos[3])
					local middle_lines = #lines > 2 and table.concat(lines, " ", 2, #lines - 1) or ""

					expr = first_line .. " " .. middle_lines .. " " .. last_line
					expr = expr:gsub("%s+", " "):gsub("^%s*(.-)%s*$", "%1") -- 清理空格
				end
			elseif mode == "n" then -- 普通模式
				-- 获取当前光标下的单词
				expr = vim.fn.expand("<cword>")
			end

			if expr and expr ~= "" then
				-- 直接使用获取到的表达式
				require("dap-view").add_expr(expr, false)
				vim.notify(string.format("已添加监视: %s", expr), vim.log.levels.INFO)
			else
				-- 没有获取到，弹出输入框
				vim.ui.input({ prompt = "输入监视表达式: " }, function(input)
					if input and input ~= "" then
						require("dap-view").add_expr(input, false)
						vim.notify(string.format("已添加监视: %s", input), vim.log.levels.INFO)
					end
				end)
			end
		end, { desc = "DAP: 智能添加监视表达式" })

		-- 通过选择器跳转到视图
		vim.keymap.set("n", "<leader>dj", function()
			local dap_view = require("dap-view")

			-- 先确保视图打开
			-- dap_view.toggle(false)

			local views = {
				{ name = "Breakpoints", id = "breakpoints", icon = " " },
				{ name = "Exceptions", id = "exceptions", icon = "󰅚 " },
				{ name = "Watches", id = "watches", icon = "󰖷 " },
				{ name = "REPL", id = "repl", icon = " " },
				{ name = "Threads", id = "threads", icon = " " },
				-- { name = "Console", id = "console", icon = " " },
				{ name = "Scopes", id = "scopes", icon = "󰩫 " },
				{ name = "Sessions", id = "sessions", icon = " " },
				{ name = "Disassembly", id = "disassembly", icon = " " },
			}

			vim.ui.select(views, {
				prompt = "🔍 Select DAP view:",
				format_item = function(item)
					return string.format("%s %-12s", item.icon, item.name, item.id)
				end,
			}, function(choice)
				if choice and choice.id then
					vim.defer_fn(function()
						require("dap-view").open()
						dap_view.jump_to_view(choice.id)
						vim.notify(string.format("✅ Jumped to %s", choice.name), vim.log.levels.INFO)
					end, 30)
				end
			end)
		end, { desc = "DAP: Select view to jump to" })

		-- 循环导航（允许从最后一个回到第一个）
		vim.keymap.set("n", "<C-=>", function()
			require("dap-view").navigate({ count = 1, wrap = true })
		end, { desc = "DAP View: Focus next view (wrap)" })

		vim.keymap.set("n", "<C-->", function()
			require("dap-view").navigate({ count = -1, wrap = true })
		end, { desc = "DAP View: Focus previous view (wrap)" })
	end,
}
