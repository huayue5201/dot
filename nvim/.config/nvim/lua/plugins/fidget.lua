-- https://github.com/j-hui/fidget.nvim

return {
	"j-hui/fidget.nvim",
	event = "VeryLazy",
	config = function()
		require("fidget").setup({
			-- 与 LSP 进度子系统相关的选项
			progress = {
				poll_rate = 0, -- 轮询进度消息的频率（ms），0 表示不主动轮询
				suppress_on_insert = false, -- 插入模式下是否抑制新消息
				ignore_done_already = false, -- 是否忽略已经完成的任务
				ignore_empty_message = false, -- 是否忽略没有内容的任务消息
				-- LSP 客户端断开时是否清除通知组
				clear_on_detach = function(client_id)
					local client = vim.lsp.get_client_by_id(client_id)
					return client and client.name or nil
				end,
				-- 如何获取进度消息的通知组 key
				notification_group = function(msg)
					return msg.lsp_client.name
				end,
				ignore = {}, -- 要忽略的 LSP 服务器列表

				-- LSP 进度消息作为通知显示时的相关选项
				display = {
					render_limit = 16, -- 同时显示的最大 LSP 消息数
					done_ttl = 3, -- 任务完成后消息保留的时间（秒）
					done_icon = "✔", -- 所有任务完成时显示的图标
					done_style = "Constant", -- 已完成任务的高亮样式
					progress_ttl = math.huge, -- 任务进行中时消息的保留时间
					progress_icon = { "dots" }, -- 任务进行中显示的图标
					progress_style = "WarningMsg", -- 进行中任务的高亮样式
					group_style = "Title", -- LSP 服务器名的高亮样式
					icon_style = "Question", -- 图标的高亮样式
					priority = 30, -- 通知组的显示优先级
					skip_history = true, -- 是否跳过通知历史记录
					format_message = require("fidget.progress.display").default_format_message, -- 格式化进度消息的函数
					format_annote = function(msg)
						return msg.title -- 格式化注释（annotation）
					end,
					format_group_name = function(group)
						return tostring(group) -- 格式化通知组名
					end,
					overrides = { -- 覆盖默认通知配置
						rust_analyzer = { name = "rust-analyzer" },
					},
				},

				-- 与 Neovim 内置 LSP 客户端相关的选项
				lsp = {
					progress_ringbuf_size = 0, -- LSP 进度 ring buffer 的大小
					log_handler = false, -- 是否记录 `$/progress` 调用日志（用于调试）
				},
			},

			-- 与通知子系统相关的选项
			notification = {
				poll_rate = 10, -- 更新并渲染通知的频率（ms）
				filter = vim.log.levels.INFO, -- 最低通知等级（如 INFO、WARN）
				history_size = 128, -- 保留在历史记录中的已移除消息数量
				override_vim_notify = false, -- 自动覆盖 vim.notify()
				configs = { default = require("fidget.notification").default_config }, -- 通知组的默认配置
				redirect = function(msg, level, opts) -- 条件性地重定向通知到其他后端
					if opts and opts.on_open then
						return require("fidget.integration.nvim-notify").delegate(msg, level, opts)
					end
				end,

				-- 通知文本显示相关选项
				view = {
					stack_upwards = true, -- 通知堆叠方向：从底部向上
					icon_separator = " ", -- 图标和组名之间的分隔符
					group_separator = "---", -- 通知组之间的分隔符
					group_separator_hl = "Comment", -- 通知组分隔符的高亮样式
					render_message = function(msg, cnt) -- 如何渲染消息内容
						return cnt == 1 and msg or string.format("(%dx) %s", cnt, msg)
					end,
				},

				-- 通知窗口和缓冲区相关选项
				window = {
					normal_hl = "Comment", -- 通知窗口的基础高亮组
					winblend = 100, -- 通知窗口的背景透明度
					border = "none", -- 通知窗口的边框样式
					zindex = 45, -- 通知窗口的层级优先级
					max_width = 0, -- 通知窗口的最大宽度
					max_height = 0, -- 通知窗口的最大高度
					x_padding = 1, -- 通知窗口右侧边距
					y_padding = 0, -- 通知窗口底部边距
					align = "bottom", -- 通知窗口对齐方式
					relative = "editor", -- 相对 Neovim 编辑器定位
				},
			},

			-- 插件集成相关选项
			integration = {
				["nvim-tree"] = {
					enable = false, -- 启用与 nvim-tree 的集成
				},
				["xcodebuild-nvim"] = {
					enable = false, -- 启用与 xcodebuild.nvim 的集成
				},
			},

			-- 日志相关选项
			logger = {
				level = vim.log.levels.WARN, -- 最低记录等级
				max_size = 10000, -- 最大日志文件大小（KB）
				float_precision = 0.01, -- 浮点数的显示精度
				path = string.format("%s/fidget.nvim.log", vim.fn.stdpath("cache")), -- 日志文件路径
			},
		})

		vim.keymap.set("n", "<leader>lm", "<cmd>Fidget history<cr>", { silent = true, desc = "查看历史消息" })
	end,
}
