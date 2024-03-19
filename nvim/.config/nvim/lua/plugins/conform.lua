-- https://github.com/stevearc/conform.nvim

return {
	"stevearc/conform.nvim", -- 使用 conform.nvim 插件
	event = "BufReadPre", -- 在 BufReadPre 事件触发时执行
	cmd = "ConformInfo", -- 定义命令 ConformInfo
	dependencies = {
		"williamboman/mason.nvim", -- 依赖于 mason.nvim 插件
	},
	keys = {
		{
			"<S-A-f>", -- 自定义快捷键 "<Shift>-<Alt>-f"
			function()
				require("conform").format({ async = true, lsp_fallback = true }) -- 格式化操作
			end,
			mode = "", -- 模式为空字符串，表示适用于所有模式
			desc = "格式化", -- 快捷键描述
		},
	},
	-- 所有 opts 中的内容都将传递给 setup() 函数
	opts = {
		-- 保存时自动格式化
		format_on_save = {
			-- These options will be passed to conform.format()
			timeout_ms = 500,
			lsp_fallback = true,
		},
		formatters_by_ft = {
			-- 配置不同文件类型的格式化器
			lua = { "stylua" }, -- Lua 文件使用 stylua 格式化器
			-- 可以继续添加其他文件类型和对应的格式化器
		},
		formatters = {
			-- 自定义格式化器参数
			shfmt = {
				prepend_args = { "-i", "2" }, -- shfmt 格式化器参数
			},
			-- 可以继续添加其他自定义格式化器和参数
		},
	},
	init = function()
		-- 设置 formatexpr，如果需要的话
		vim.o.formatexpr = "v:lua.require'conform'.formatexpr()"
	end,
}
