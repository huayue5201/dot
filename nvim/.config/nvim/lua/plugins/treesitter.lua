-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = "VeryLazy", -- keep for lazy loading
	dependencies = {
		-- https://github.com/JoosepAlviste/nvim-ts-context-commentstring
		"JoosepAlviste/nvim-ts-context-commentstring",
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
		"nvim-treesitter/nvim-treesitter-textobjects",
		-- https://github.com/nvim-treesitter/nvim-treesitter-context
		"nvim-treesitter/nvim-treesitter-context",
	},
	config = function()
		require("nvim-treesitter.configs").setup({
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"markdown",
				"markdown_inline",
				"regex",
				"bash",
				"norg",
			},
			-- 同步安装解析器
			sync_install = true,
			-- 自动安装解析器
			auto_install = true,
			-- 缩进模块
			indent = {
				enable = true,
			},
			-- 高亮模块配置
			highlight = {
				enable = true,
				-- Or use a function for more flexibility, e.g. to disable slow treesitter highlight for large files
				disable = function(lang, buf)
					local max_filesize = 100 * 1024 -- 100 KB
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						return true
					end
				end,
				-- 关闭vim自带语法高亮引擎，只使用treesitter.
				-- 设置为true，可能会降低neovim速度。
				additional_vim_regex_highlighting = false,
			},
			-- 增量选择模块
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<CR>",
					node_incremental = "<CR>",
					node_decremental = "<BS>",
					scope_incremental = "<TAB>",
				},
			},
			-- JoosepAlviste/nvim-ts-context-commentstring
			context_commentstring = {
				enable = true,
			},
			-- nvim-treesitter/nvim-treesitter-textobjects
			-- TODO: nvim-treesitter-textobjects配置未完善
			textobjects = {
				lsp_interop = {
					enable = true,
					border = "none",
					floating_preview_opts = {},
					peek_definition_code = {
						["<leader>k"] = "@function.outer",
						["<leader>k"] = "@class.outer",
					},
				},
				select = {
					enable = true,
					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = true,
					keymaps = {
						-- You can use the capture groups defined in textobjects.scm
						["af"] = "@function.outer",
						["if"] = "@function.inner",
						["ac"] = "@class.outer",
						-- You can optionally set descriptions to the mappings (used in the desc parameter of
						-- nvim_buf_set_keymap) which plugins like which-key display
						["ic"] = { query = "@class.inner", desc = "Select inner part of a class region" },
						-- You can also use captures from other query groups like `locals.scm`
						["as"] = { query = "@scope", query_group = "locals", desc = "Select language scope" },
					},
					selection_modes = {
						["@parameter.outer"] = "v", -- charwise
						["@function.outer"] = "V", -- linewise
						["@class.outer"] = "<c-v>", -- blockwise
					},
					include_surrounding_whitespace = true,
				},
			},
		})
	end,
}
