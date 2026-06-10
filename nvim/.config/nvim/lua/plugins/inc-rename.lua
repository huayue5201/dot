-- https://github.com/smjonas/inc-rename.nvim

return {
	"smjonas/inc-rename.nvim",
	event = "LspAttach",
	config = function()
		require("inc_rename").setup({
			-- 命令名称
			cmd_name = "IncRename",

			-- 用于高亮标识符新名称的语法高亮组
			hl_group = "Substitute",

			-- 是否预览空的新名称；如果设为 false，则取消命令预览
			preview_empty_name = false,

			-- 重命名操作完成后，是否显示"在 N 个文件中重命名了 M 处"的消息
			show_message = true,

			-- 是否将 "IncRename" 命令保存到命令行历史中
			-- （设为 false 可避免因命令预览行为导致访问历史条目时出现的问题）
			save_in_cmdline_history = true,

			-- 外部输入缓冲区的类型（目前支持 "dressing" 或 "snacks"）
			input_buffer_type = nil,

			-- 重命名后运行的回调函数，接收结果表（来自 LSP 处理器）作为参数
			post_hook = nil,
		})

		vim.keymap.set("n", "grn", ":IncRename ")
	end,
}
