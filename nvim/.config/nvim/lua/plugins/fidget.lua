-- https://chatgpt.com/c/690ca0ea-cd00-8327-9ded-241e65932096

return {
	"j-hui/fidget.nvim",
	config = function(_, opts)
		require("fidget").setup({
			-- 进度 (LSP “$/progress” 相关) 配置
			progress = {
				display = {
					spinner = "dots",
					done_icon = "✔",
					progress_style = "WarningMsg",
					done_style = "Comment",
				},
			},
			-- 通知窗口（非进度，只是普通通知，比如 vim.notify）配置
			notification = {
				poll_rate = 10,
				filter = vim.log.levels.INFO,
				history_size = 64,
				override_vim_notify = false, -- 若启 true 则把 vim.notify 全部改为 fidget 显示
				configs = {
					default = require("fidget.notification").default_config,
				},
				redirect = function(msg, level, opts)
					if opts and opts.on_open then
						return require("fidget.integration.nvim-notify").delegate(msg, level, opts)
					end
				end,
				view = {
					stack_upwards = false,
					align = "message",
					reflow = false,
					icon_separator = " › ",
					group_separator = "──",
					group_separator_hl = "Comment",
					line_margin = 1,
					render_message = function(msg, count)
						return (count == 1 and msg) or string.format("(%dx) %s", count, msg)
					end,
				},
				window = {
					normal_hl = "Comment",
					winblend = 80,
					-- border = "none",
					zindex = 40,
					max_width = 50,
					max_height = 10,
					x_padding = 1,
					y_padding = 0,
					-- align = "bottomright",
					relative = "editor",
					avoid = { "NvimTree", "neo-tree" },
				},
				integration = {
					["nvim-tree"] = {
						enable = true,
					},
				},
				logger = {
					level = vim.log.levels.WARN,
					max_size = 1000,
					float_precision = 0.01,
					path = string.format("%s/fidget.log", vim.fn.stdpath("cache")),
				},
			},
		})
	end,
}
