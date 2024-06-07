-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>oa", desc = "符号树" },
		{ "<leader>a", desc = "符号树浮窗" },
	},
	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		vim.cmd([[
              hi link AerialClass Type
              hi link AerialClassIcon Special
              hi link AerialFunction Special
              hi AerialFunctionIcon guifg=#cb4b16 guibg=NONE guisp=NONE gui=NONE cterm=NONE

              " There's also this group for the fallback of the text if a specific
              " class highlight isn't defined
              hi link AerialNormal Normal
              " There's also this group for the cursor position
              hi link AerialLine QuickFixLine
              " If highlight_mode="split_width", you can set a separate color for the
              " non-current location highlight
              hi AerialLineNC guibg=Gray

              " You can customize the guides (if show_guide=true)
              hi link AerialGuide Comment
              " You can set a different guide color for each level
              hi AerialGuide1 guifg=Red
              hi AerialGuide2 guifg=Blue
    ]])
		require("aerial").setup({
			-- optionally use on_attach to set keymaps when aerial has attached to a buffer
			on_attach = function(bufnr)
				-- Jump forwards/backwards with '{' and '}'
				vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
				vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
			end,
			-- 控制aerial窗口的宽度和布局选项
			-- 包括最大宽度、宽度、最小宽度、默认打开方向和位置
			layout = {
				max_width = { 40, 0.2 },
				width = nil,
				min_width = 30,
				default_direction = "prefer_right",
				placement = "window",
			},
			-- List of enum values that configure when to auto-close the aerial window
			--   unfocus       - close aerial when you leave the original source window
			--   switch_buffer - close aerial when you change buffers in the source window
			--   unsupported   - close aerial when attaching to a buffer that has no symbol source
			close_automatic_events = { "switch_buffer" },
			filter_kind = false,
			highlight_on_hover = true,
			autojump = true,
			-- 折叠
			manage_folds = true,
			link_folds_to_tree = true,
			show_guides = true,
			nav = {
				-- 导航窗口中的键盘映射
				keymaps = {
					["<CR>"] = "actions.jump", -- 跳转到选中的符号
					["<2-LeftMouse>"] = "actions.jump", -- 同样跳转到选中的符号
					["<C-v>"] = "actions.jump_vsplit", -- 垂直分割窗口并跳转
					["<C-s>"] = "actions.jump_split", -- 水平分割窗口并跳转
					["h"] = "actions.left", -- 向左移动焦点
					["l"] = "actions.right", -- 向右移动焦点
					["<C-c>"] = "actions.close", -- 关闭导航窗口
					["<esc>"] = "actions.close", -- 关闭导航窗口
					["q"] = "actions.close", -- 关闭导航窗口
				},
			},
		})
		-- You probably also want to set a keymap to toggle aerial
		vim.keymap.set("n", "<leader>oa", "<cmd>AerialToggle!<CR>")
		vim.keymap.set("n", "<leader>a", "<cmd>AerialNavToggl<CR>")
	end,
}
