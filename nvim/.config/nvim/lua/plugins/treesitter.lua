-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = "VeryLazy",
	-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
	dependencies = {
		"nvim-treesitter/nvim-treesitter-textobjects",
		-- https://github.com/LiadOz/nvim-dap-repl-highlights
		"LiadOz/nvim-dap-repl-highlights",
	},
	config = function()
		local parser_configs = require("nvim-treesitter.parsers").get_parser_configs()
		parser_configs.qf = {
			install_info = {
				url = "https://github.com/OXY2DEV/tree-sitter-qf",
				files = { "src/parser.c" },
				branch = "main",
			},
		}
		require("nvim-dap-repl-highlights").setup()
		require("nvim-treesitter.configs").setup({
			-- 是否同步安装解析器
			sync_install = true,
			-- 是否自动安装解析器
			auto_install = true,
			-- 忽略安装的解析器模块
			-- ignore_install = { "text" },
			-- 启用缩进模块
			indent = {
				enable = true,
				disable = function(lang, buf)
					local max_lines = 10000
					local line_count = vim.api.nvim_buf_line_count(buf)
					if line_count > max_lines then
						vim.schedule(function()
							vim.notify("🧹 Disabled Treesitter indent for large file (" .. line_count .. " lines)")
						end)
						return true
					end
				end,
			},
			-- 高亮模块配置
			highlight = {
				enable = true,
				disable = function(lang, buf)
					local max_filesize = 5 * 1024 * 1024 -- 5 MB
					local ok, stats = pcall(vim.loop.fs_stat, vim.api.nvim_buf_get_name(buf))
					if ok and stats and stats.size > max_filesize then
						vim.schedule(function()
							vim.notify(
								string.format(
									"🌲 Disabled Treesitter highlight for large file (%.2f MB)",
									stats.size / (1024 * 1024)
								)
							)
						end)
						return true
					end
				end,
				-- 关闭 vim 自带语法高亮引擎，只使用 Treesitter
				additional_vim_regex_highlighting = false,
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<tab>", -- set to `false` to disable one of the mappings
					node_incremental = "<tab>",
					scope_incremental = "<cr>",
					node_decremental = "<Backspace>",
				},
			},
			-- 确保所需的语言解析器被安装
			ensure_installed = {
				"lua",
				"vim",
				"vimdoc",
				"markdown",
				"markdown_inline",
				"regex",
				"bash",
				"c",
				"cmake",
				"json",
				"rust",
				"qf",
				"comment",
				"typescript",
				"dap_repl",
			},
			textobjects = {
				swap = {
					enable = true,
					swap_next = {
						["<s-a-l>"] = "@parameter.inner",
					},
					swap_previous = {
						["<s-a-h>"] = "@parameter.inner",
					},
				},
				move = {
					enable = true,
					set_jumps = true, -- whether to set jumps in the jumplist
					goto_next_start = {
						["]f"] = { query = "@function.outer", desc = "Next function start" },
						["]s"] = { query = "@local.scope", query_group = "locals", desc = "Next scope" },
						["]z"] = { query = "@fold", query_group = "folds", desc = "Next fold" },
					},
					goto_previous_start = {
						["[f"] = { query = "@function.outer", desc = "Previous function start" },
						["[s"] = { query = "@local.scope", query_group = "locals", desc = "Previous scope" },
						["[z"] = { query = "@fold", query_group = "folds", desc = "Previous fold" },
					},
				},
				select = {
					enable = true,
					-- Automatically jump forward to textobj, similar to targets.vim
					lookahead = true,
					keymaps = {
						-- You can use the capture groups defined in textobjects.scm
						["af"] = { query = "@function.outer", desc = "选择函数内部" },
						["if"] = { query = "@function.inner", desc = "选择整个函数" },
						-- 选择类（适用于支持类的语言，如 Rust）
						-- ["ac"] = { query = "@class.outer", desc = "选择类" },
						["ic"] = { query = "@class.inner", desc = "选择类内部" },
						-- You can optionally set descriptions to the mappings (used in the desc parameter of
						-- nvim_buf_set_keymap) which plugins like which-key display
						-- You can also use captures from other query groups like `locals.scm`
						["as"] = { query = "@local.scope", query_group = "locals", desc = "Select language scope" },
					},
					-- You can choose the select mode (default is charwise 'v')
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * method: eg 'v' or 'o'
					-- and should return the mode ('v', 'V', or '<c-v>') or a table
					-- mapping query_strings to modes.
					selection_modes = {
						["@parameter.outer"] = "v", -- charwise
						["@function.outer"] = "V", -- linewise
						["@class.outer"] = "<c-v>", -- blockwise
					},
					-- If you set this to `true` (default is `false`) then any textobject is
					-- extended to include preceding or succeeding whitespace. Succeeding
					-- whitespace has priority in order to act similarly to eg the built-in
					-- `ap`.
					--
					-- Can also be a function which gets passed a table with the keys
					-- * query_string: eg '@function.inner'
					-- * selection_mode: eg 'v'
					-- and should return true or false
					include_surrounding_whitespace = true,
				},
			},
		})
	end,
}
