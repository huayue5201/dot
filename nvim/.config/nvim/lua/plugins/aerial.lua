-- https://github.com/stevearc/aerial.nvim

return {
	"stevearc/aerial.nvim",
	keys = {
		{ "<leader>te", "<cmd>AerialToggle<CR>", desc = "大纲/侧边栏" },
		{ "<leader>tw", "<cmd>AerialNavToggle<CR>", desc = "大纲/浮窗" },
	},
	dependencies = {
		"nvim-treesitter/nvim-treesitter",
		"nvim-tree/nvim-web-devicons",
	},
	config = function()
		-- 颜色高亮
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
			on_attach = function(bufnr)
				-- Jump forwards/backwards with '{' and '}'
				vim.keymap.set("n", "{", "<cmd>AerialPrev<CR>", { buffer = bufnr })
				vim.keymap.set("n", "}", "<cmd>AerialNext<CR>", { buffer = bufnr })
			end,
			-- Priority list of preferred backends for aerial.
			-- This can be a filetype map (see :help aerial-filetype-map)
			backends = { "treesitter", "lsp", "markdown", "man" },

			layout = {
				-- aerial边栏大小
				max_width = { 40, 0.2 },
				width = nil,
				min_width = 35,

				-- 窗口位置
				-- Enum: prefer_right, prefer_left, right, left, float
				default_direction = "prefer_left",
			},
			-- Show box drawing characters for the tree hierarchy
			-- 层级线条支持
			show_guides = true,

			-- Customize the characters used when show_guides = true
			guides = {
				-- When the child item has a sibling below it
				mid_item = "├─",
				-- When the child item is the last in the list
				last_item = "└─",
				-- When there are nested child guides to the right
				nested_top = "│ ",
				-- Raw indentation
				whitespace = "  ",
			},
		})
	end,
}
