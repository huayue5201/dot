-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>ls", desc = "符号树" },
		{ "<leader>s", desc = "符号树浮窗" },
		{ "<leader>fl", desc = "fzf符号树" },
	},
	-- Optional dependencies
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		require("aerial").setup({
			backends = { "lsp", "treesitter", "markdown" },
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
				min_width = 38,
				default_direction = "prefer_right",
				placement = "window",
			},
			highlight_on_hover = true,
			autojump = true,
			-- 折叠
			manage_folds = true,
			show_guides = true,
			nav = {
				-- Jump to symbol in source window when the cursor moves
				autojump = true,
				-- Show a preview of the code in the right column, when there are no child symbols
				preview = false,
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
			lsp = {
				-- If true, fetch document symbols when LSP diagnostics update.
				diagnostics_trigger_update = true,

				-- Set to false to not update the symbols when there are LSP errors
				update_when_errors = true,

				-- How long to wait (in ms) after a buffer change before updating
				-- Only used when diagnostics_trigger_update = false
				update_delay = 300,

				-- Map of LSP client name to priority. Default value is 10.
				-- Clients with higher (larger) priority will be used before those with lower priority.
				-- Set to -1 to never use the client.
				priority = {
					-- pyright = 10,
				},
			},
		})
		-- You probably also want to set a keymap to toggle aerial
		vim.keymap.set("n", "<leader>ls", "<cmd>AerialToggle!<CR>")
		vim.keymap.set("n", "<leader>s", "<cmd>AerialNavToggl<CR>")
		vim.cmd([[nmap <silent> <leader>fl <cmd>call aerial#fzf()<cr>]])
	end,
}
