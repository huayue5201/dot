-- TODO: https://github.com/mistweaverco/kulala.nvim
-- https://github.com/rest-nvim/rest.nvim

return {
	"rest-nvim/rest.nvim",
	ft = "http",
	build = false,
	dependencies = {
		"nvim-neotest/nvim-nio",
		"nvim-treesitter/nvim-treesitter",
		{
			-- Lazy.nvim does not recognize this library's rocksfile, so add it
			-- to package path manually.
			-- https://github.com/manoelcampos/xml2lua
			"manoelcampos/xml2lua",
			config = function(plugin)
				package.path = package.path .. ";" .. plugin.dir .. "/?.lua"
			end,
		},
		-- https://github.com/lunarmodules/lua-mimetypes
		"lunarmodules/lua-mimetypes",
	},
	config = function()
		---@type rest.Opts
		---rest.nvim 默认配置
		---@class rest.Config
		local default_config = {
			---@type table<string, fun():string> 自定义动态变量表
			custom_dynamic_variables = {},

			---@class rest.Config.Request
			request = {
				---@type boolean 跳过 SSL 证书验证，对于未知证书很有用
				skip_ssl_verification = false,

				---默认请求钩子
				---@class rest.Config.Request.Hooks
				hooks = {
					---@type boolean 发起请求前对 URL 进行编码
					encode_url = true,
					---@type string 当 `User-Agent` 头为空时设置此值
					user_agent = "rest.nvim v" .. require("rest-nvim.api").VERSION,
					---@type boolean 当请求体存在且 `Content-Type` 头为空时自动设置
					set_content_type = true,
				},
			},

			---@class rest.Config.Response
			response = {
				---默认响应钩子
				---@class rest.Config.Response.Hooks
				hooks = {
					---@type boolean 在响应界面上解码请求 URL 片段以提高可读性
					decode_url = true,
					---@type boolean 使用 `gq` 命令格式化响应体
					format = true,
				},
			},

			---@class rest.Config.Clients
			clients = {
				---@class rest.Config.Clients.Curl
				curl = {
					---要显示的统计信息，使用 cURL 的 `--write-out` 标志变量
					---参见 `man curl` 了解 `--write-out` 标志
					---@type RestStatisticsStyle[]
					statistics = {
						{ id = "time_total", winbar = "take", title = "耗时" },
						{ id = "size_download", winbar = "size", title = "下载大小" },
					},

					---curl 特定的请求/响应钩子
					---@class rest.Config.Clients.Curl.Opts
					opts = {
						---@type boolean 当 `Accept-Encoding` 头包含 `gzip` 时添加 `--compressed` 参数
						set_compressed = false,
						---@type table<string, Certificate> 每个域名的证书表
						certificates = {},
					},
				},
			},

			---@class rest.Config.Cookies
			cookies = {
				---@type boolean 是否启用 cookie 支持
				enable = true,
				---@type string Cookie 存储文件路径
				path = vim.fs.joinpath(vim.fn.stdpath("data") --[[@as string]], "rest-nvim.cookies"),
			},

			---@class rest.Config.Env
			env = {
				---@type boolean 是否启用环境变量支持
				enable = true,
				---@type string 环境文件匹配模式
				pattern = ".*%.env.*",
				---@type fun():string[] 查找环境文件的函数
				find = function()
					local config = require("rest-nvim.config")
					return vim.fs.find(function(name, _)
						return name:match(config.env.pattern)
					end, {
						path = vim.fn.getcwd(), -- 从当前工作目录开始查找
						type = "file", -- 只查找文件
						limit = math.huge, -- 不限制查找数量
					})
				end,
			},

			---@class rest.Config.UI
			ui = {
				---@type boolean 是否在结果面板设置 winbar
				winbar = true,

				---@class rest.Config.UI.Keybinds
				keybinds = {
					---@type string 切换到上一个结果面板的快捷键
					prev = "H",
					---@type string 切换到下一个结果面板的快捷键
					next = "L",
				},
			},

			---@class rest.Config.Highlight
			highlight = {
				---@type boolean 是否启用当前请求高亮
				enable = true,
				---@type number 请求高亮显示持续时间（毫秒）
				timeout = 750,
			},

			---@see vim.log.levels
			---@type integer 日志级别
			_log_level = vim.log.levels.WARN,
		}

		-- rest.nvim 快捷键映射
		-- 前缀: <leader>r (默认 leader 为空格键，所以是空格 + r)

		local map = vim.api.nvim_set_keymap
		local opts = { noremap = true, silent = true }

		-- ========== 基础操作 ==========
		-- 运行当前光标下的请求
		map("n", "<leader>ort", "<Cmd>Rest run<CR>", vim.tbl_extend("force", opts, { desc = "运行当前请求" }))

		-- 运行最后一个请求
		map(
			"n",
			"<leader>orl",
			"<Cmd>Rest last<CR>",
			vim.tbl_extend("force", opts, { desc = "运行最后一个请求" })
		)

		-- 按名称运行请求 (会提示输入名称)
		map(
			"n",
			"<leader>orn",
			"<Cmd>Rest run<Space>",
			vim.tbl_extend("force", opts, { desc = "按名称运行请求" })
		)

		-- ========== 结果面板 ==========
		-- 打开结果面板
		map("n", "<leader>oro", "<Cmd>Rest open<CR>", vim.tbl_extend("force", opts, { desc = "打开结果面板" }))

		-- 关闭结果面板 (使用自带快捷键，这里不重复绑定)

		-- ========== 文件管理 ==========
		-- 编辑日志文件
		map("n", "<leader>orlg", "<Cmd>Rest logs<CR>", vim.tbl_extend("force", opts, { desc = "编辑日志文件" }))

		-- 编辑 cookie 文件
		map(
			"n",
			"<leader>orc",
			"<Cmd>Rest cookies<CR>",
			vim.tbl_extend("force", opts, { desc = "编辑 Cookie 文件" })
		)

		-- ========== 环境变量管理 ==========
		-- 显示当前注册的 dotenv 文件
		map(
			"n",
			"<leader>orss",
			"<Cmd>Rest env show<CR>",
			vim.tbl_extend("force", opts, { desc = "显示环境变量文件" })
		)

		-- 选择并注册 .env 文件 (交互式选择)
		map(
			"n",
			"<leader>orse",
			"<Cmd>Rest env select<CR>",
			vim.tbl_extend("force", opts, { desc = "选择环境变量文件" })
		)

		-- 手动设置 .env 文件路径
		map(
			"n",
			"<leader>orsp",
			"<Cmd>Rest env set<Space>",
			vim.tbl_extend("force", opts, { desc = "设置环境变量文件路径" })
		)

		-- ========== 视觉模式支持 ==========
		-- 视觉模式下运行选中的请求
		map("v", "<leader>ort", "<Cmd>Rest run<CR>", vim.tbl_extend("force", opts, { desc = "运行选中的请求" }))
	end,
}
