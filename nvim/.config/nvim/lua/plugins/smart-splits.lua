-- https://github.com/mrjones2014/smart-splits.nvim

return {
	"mrjones2014/smart-splits.nvim",
	event = "WinNew",
	config = function()
		---@diagnostic disable-next-line: missing-fields
		require("smart-splits").setup({
			ignored_filetypes = {
				"nofile",
				"quickfix",
				"prompt",
				"NvimTree",
				"neo-tree",
				"toggleterm",
			},
			ignored_buftypes = {
				"terminal",
			},
			zellij_move_focus_or_tab = true,
		})
		-- recommended mappings
		-- resizing splits
		-- these keymaps will also accept a range,
		-- for example `10<A-h>` will `resize_left` by `(10 * config.default_amount)`
		-- 调整窗口 / tmux pane 大小
		vim.keymap.set(
			"n",
			"<A-h>",
			require("smart-splits").resize_left,
			{ desc = "向左调整窗口 / tmux 面板大小" }
		)
		vim.keymap.set(
			"n",
			"<A-j>",
			require("smart-splits").resize_down,
			{ desc = "向下调整窗口 / tmux 面板大小" }
		)
		vim.keymap.set(
			"n",
			"<A-k>",
			require("smart-splits").resize_up,
			{ desc = "向上调整窗口 / tmux 面板大小" }
		)
		vim.keymap.set(
			"n",
			"<A-l>",
			require("smart-splits").resize_right,
			{ desc = "向右调整窗口 / tmux 面板大小" }
		)

		-- 在窗口 / tmux 面板之间移动光标
		vim.keymap.set(
			"n",
			"<S-C-h>",
			require("smart-splits").move_cursor_left,
			{ desc = "移动到左侧窗口 / tmux 面板" }
		)
		vim.keymap.set(
			"n",
			"<S-C-j>",
			require("smart-splits").move_cursor_down,
			{ desc = "移动到下方窗口 / tmux 面板" }
		)
		vim.keymap.set(
			"n",
			"<S-C-k>",
			require("smart-splits").move_cursor_up,
			{ desc = "移动到上方窗口 / tmux 面板" }
		)
		vim.keymap.set(
			"n",
			"<S-C-l>",
			require("smart-splits").move_cursor_right,
			{ desc = "移动到右侧窗口 / tmux 面板" }
		)
		vim.keymap.set(
			"n",
			"<C-[>",
			require("smart-splits").move_cursor_previous,
			{ desc = "返回上一个窗口 / tmux 面板" }
		)

		-- 在窗口之间交换 buffer
		vim.keymap.set(
			"n",
			"<leader><leader>h",
			require("smart-splits").swap_buf_left,
			{ desc = "与左侧窗口交换 buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader><leader>j",
			require("smart-splits").swap_buf_down,
			{ desc = "与下方窗口交换 buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader><leader>k",
			require("smart-splits").swap_buf_up,
			{ desc = "与上方窗口交换 buffer" }
		)
		vim.keymap.set(
			"n",
			"<leader><leader>l",
			require("smart-splits").swap_buf_right,
			{ desc = "与右侧窗口交换 buffer" }
		)
	end,
}
