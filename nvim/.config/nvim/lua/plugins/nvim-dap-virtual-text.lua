-- https://github.com/theHamsta/nvim-dap-virtual-text

return {
	"theHamsta/nvim-dap-virtual-text",
	lazy = true,
	dependencies = "nvim-treesitter/nvim-treesitter",
	config = function()
		require("nvim-dap-virtual-text").setup({
			enabled = true, -- 启用此插件（默认启用）
			enabled_commands = true, -- 创建命令 `DapVirtualTextEnable`、`DapVirtualTextDisable`、`DapVirtualTextToggle`，
			-- 以及 `DapVirtualTextForceRefresh`（用于在调试适配器未通知其终止时刷新虚拟文本）
			highlight_changed_variables = true, -- 高亮显示更改过的变量值，使用 `NvimDapVirtualTextChanged`，否则始终使用 `NvimDapVirtualText`
			highlight_new_as_changed = true, -- 将新变量以与已更改的变量相同的方式高亮显示（如果启用了 `highlight_changed_variables`）
			show_stop_reason = true, -- 在因异常停止时显示停止原因
			commented = false, -- 是否在虚拟文本前加上注释符号
			only_first_definition = true, -- 仅在第一次定义时显示虚拟文本（如果有多个定义）
			all_references = false, -- 是否显示变量的所有引用的虚拟文本（不仅限于定义）
			clear_on_continue = true, -- 在 "continue" 时清除虚拟文本（可能会导致在单步调试时出现闪烁）
			-- 虚拟文本的位置，参见 `:h nvim_buf_set_extmark()`，默认尝试将虚拟文本内联显示。使用 'eol' 将虚拟文本放置在行尾。
			-- virt_text_pos = "eol",

			-- 实验性功能：
			all_frames = false, -- 是否为所有堆栈帧显示虚拟文本，而不仅仅是当前堆栈帧。仅对 `debugpy` 在我的机器上有效。
			virt_lines = false, -- 是否显示虚拟行而非虚拟文本（可能会导致闪烁！）
			virt_text_win_col = nil, -- 将虚拟文本定位到固定的窗口列（从第一个文本列开始），
			-- 例如，设置为 80 会将其定位在第 80 列，参见 `:h nvim_buf_set_extmark()`
		})
	end,
}
