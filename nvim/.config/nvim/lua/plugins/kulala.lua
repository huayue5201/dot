-- https://github.com/mistweaverco/kulala.nvim

return {
	"mistweaverco/kulala.nvim",
	-- 在会话保存/恢复前加载，确保 VimLeavePre 和 SessionLoadPost 钩子被注册
	event = { "SessionLoadPost", "VimLeavePre" },
	-- 查看 opts.lsp.enforce_external_script_naming_convention
	-- 以限制 LSP 功能只对 *.http, *.http.js, *.http.ts 和 *.http.lua 文件生效
	-- ft = { "http", "rest", "javascript", "lua", "rust" },
	opts = {
		kulala_core = {
			path = nil,
			timeout = 60000,
			data_dir = nil,
			download_url = "https://github.com/mistweaverco/kulala-core/releases/download/%s/%s",
		},
		session = {
			restore = true,
		},
		default_env = "default",
		environment_scope = "b",
		vscode_rest_client_environmentvars = false,

		response_format = {
			indent = 2,
			expand_tabs = true,
			sort_keys = false,
		},
		ui = {
			display_mode = "float", -- 你这里改成了 float，没问题
			split_direction = "right",
			win_opts = { bo = {}, wo = {} },
			default_view = "body",
			winbar = true,
			default_winbar_panes = { "body", "headers", "verbose", "script_output", "report" },
			winbar_labels = {
				body = "响应体",
				headers = "响应头",
				headers_body = "全部",
				verbose = "详细信息",
				script_output = "脚本输出",
				stats = "统计信息",
				report = "报告",
				help = "帮助",
			},
			winbar_labels_keymaps = true,
			show_variable_info_text = false,
			show_icons = "on_request",
			icons = {
				inlay = {
					loading = "⏳",
					done = "✔",
					error = "✘",
				},
				lualine = "🐼",
				textHighlight = "WarningMsg",
				loadingHighlight = "Normal",
				doneHighlight = "String",
				errorHighlight = "ErrorMsg",
			},
			show_request_summary = true,
			max_response_size = 32768,
			max_request_size = 2048,
			report = {
				show_script_output = true,
				show_asserts_output = true,
				show_summary = true,
				headersHighlight = "Special",
				successHighlight = "String",
				errorHighlight = "Error",
			},
			scratchpad_default_contents = {
				"@MY_TOKEN_NAME=my_token_value",
				"",
				"# @name scratchpad",
				"POST https://echo.kulala.app/post HTTP/1.1",
				"accept: application/json",
				"content-type: application/json",
				"",
				"{",
				'  "foo": "bar"',
				"}",
			},
		},

		lsp = {
			enable = true,
			filetypes = {
				"http",
				"rest",
				"javascript",
				"typescript",
				"lua",
			},
			enforce_external_script_naming_convention = true,
			keymaps = false,
			on_attach = nil,
		},

		debug = 3,
		generate_bug_report = false,

		-- 重要：保持 false，因为你在下方 config 函数里自定义了快捷键
		global_keymaps = false,
		global_keymaps_prefix = "<leader>R",
		kulala_keymaps = true,
		kulala_keymaps_prefix = "",
	},
	config = function(_, opts)
		-- 调用 setup 并传入配置
		require("kulala").setup(opts)

		local kulala = require("kulala")

		-- 发送请求
		vim.keymap.set({ "n", "v" }, "<leader>ors", function()
			kulala.run()
		end, { desc = "发送请求" })

		-- 发送所有请求
		vim.keymap.set({ "n", "v" }, "<leader>ora", function()
			kulala.run_all()
		end, { desc = "发送所有请求" })

		-- 【修正】打开草稿板 - scratchpad 本身就是一个函数
		vim.keymap.set("n", "<leader>orb", function()
			kulala.scratchpad() -- 直接调用，不是 .open()
		end, { desc = "打开草稿板" })

		-- 重放上次请求
		vim.keymap.set("n", "<leader>orr", function()
			kulala.replay()
		end, { desc = "重放上次请求" })

		-- 停止当前请求
		vim.keymap.set("n", "<leader>orc", function()
			kulala.stop()
		end, { desc = "停止当前请求" })

		-- 切换响应视图
		vim.keymap.set("n", "<leader>orv", function()
			kulala.toggle_view()
		end, { desc = "切换响应视图" })

		-- 复制为 curl 命令
		vim.keymap.set("n", "<leader>ory", function()
			kulala.copy_as_curl()
		end, { desc = "复制为 Curl 命令" })
	end,
}
