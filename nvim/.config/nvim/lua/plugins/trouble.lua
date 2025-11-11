-- https://github.com/folke/trouble.nvim

return {
	"folke/trouble.nvim",
	cmd = "Trouble",
	keys = {
		{
			"<leader>xx",
			"<cmd>Trouble diagnostics toggle<cr>",
			desc = "Diagnostics (Trouble)",
		},
		{
			"<leader>xX",
			"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
			desc = "Buffer Diagnostics (Trouble)",
		},
		{
			"<leader>es",
			"<cmd>Trouble symbols toggle focus=false<cr>",
			desc = "Symbols (Trouble)",
		},
		{
			"<leader>el",
			"<cmd>Trouble lsp toggle focus=false win.position=right<cr>",
			desc = "LSP Definitions / references / ... (Trouble)",
		},
		{
			"<leader>xL",
			"<cmd>Trouble loclist toggle<cr>",
			desc = "Location List (Trouble)",
		},
		{
			"<leader>xQ",
			"<cmd>Trouble qflist toggle<cr>",
			desc = "Quickfix List (Trouble)",
		},
	},
	config = function()
		require("trouble").setup({
			---@class trouble.Mode: trouble.Config,trouble.Section.spec
			---@field desc? string 描述信息
			---@field sections? string[] 章节列表

			---@class trouble.Config 配置类
			---@field mode? string 模式
			---@field config? fun(opts:trouble.Config) 配置函数
			---@field formatters? table<string,trouble.Formatter> 自定义格式化器
			---@field filters? table<string, trouble.FilterFn> 自定义过滤器
			---@field sorters? table<string, trouble.SorterFn> 自定义排序器
			auto_close = false, -- 没有项目时自动关闭
			auto_open = false, -- 有项目时自动打开
			auto_refresh = true, -- 打开时自动刷新
			auto_jump = true, -- 只有一个项目时自动跳转
			auto_preview = false, -- 在项目上时自动打开预览
			focus = true, -- 打开时聚焦窗口
			restore = true, -- 打开时恢复列表中的最后位置
			follow = true, --  开启“光标跟随”
			indent_guides = true, -- 显示缩进参考线
			max_items = 200, -- 每个章节最多显示的项目数量限制
			multiline = true, -- 渲染多行消息
			pinned = false, -- 固定时，打开的 trouble 窗口将绑定到当前缓冲区
			warn_no_results = true, -- 没有结果时显示警告
			open_no_results = false, -- 没有结果时打开 trouble 窗口
			---@type trouble.Window.opts
			win = {}, -- 结果窗口的窗口选项。可以是分割窗口或浮动窗口。
			-- 预览窗口的窗口选项。可以是分割窗口、浮动窗口，
			-- 或者是 `main` 以在主编辑器窗口中显示预览。
			---@type trouble.Window.opts
			preview = {
				type = "main",
				-- 当缓冲区尚未加载时，预览窗口将在仅启用语法高亮的临时缓冲区中创建。
				-- 设置为 false，如果你希望预览始终是真实加载的缓冲区。
				scratch = true,
			},
			-- 节流/防抖设置。通常不应更改。
			---@type table<string, number|{ms:number, debounce?:boolean}>
			throttle = {
				refresh = 20, -- 需要时获取新数据
				update = 10, -- 更新窗口
				render = 10, -- 渲染窗口
				follow = 100, -- 跟随当前项目
				preview = { ms = 100, debounce = true }, -- 显示当前项目的预览
			},
			-- 键位映射可以设置为内置操作的名称，
			-- 或者你可以定义自己的自定义操作。
			---@type table<string, trouble.Action.spec|false>
			---@type table<string, trouble.Mode>
			modes = {
				-- 源定义自己的模式，你可以直接使用，
				-- 或者像下面的示例一样覆盖
				lsp_references = {
					-- 一些模式是可配置的，详见源代码
					params = {
						include_declaration = true, -- 包含声明
					},
				},
				-- LSP 基础模式，用于：
				-- * lsp_definitions, lsp_references, lsp_implementations
				-- * lsp_type_definitions, lsp_declarations, lsp_command
				lsp_base = {
					params = {
						-- 不在结果中包含当前位置
						include_current = true,
					},
				},
				-- 扩展 lsp_document_symbols 的更高级示例
				symbols = {
					desc = "文档符号",
					mode = "lsp_document_symbols",
					win = {
						type = "split",
						position = "right", -- 可选：bottom | top | left | right | float
						size = 70, -- ← 窗口宽度（右侧）或高度（底部）
					}, -- 窗口位置在右侧
				},
			},
			-- 图标配置
			icons = {
				---@type trouble.Indent.symbols
				indent = {
					top = "│ ", -- 顶部缩进
					middle = "├╴", -- 中间缩进
					-- last = "└╴", -- 最后缩进
					-- last = "-╴", -- 最后缩进（替代样式）
					last = "╰╴", -- 圆角样式
					fold_open = " ", -- 打开折叠
					fold_closed = " ", -- 关闭折叠
					ws = "  ", -- 空白
				},
			},
		})
	end,
}
