-- https://github.com/nvim-treesitter/nvim-treesitter

return {
	"nvim-treesitter/nvim-treesitter",
	build = ":TSUpdate",
	event = "VeryLazy",
	dependencies = {
		-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects
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
			},
			-- 高亮模块配置
			highlight = {
				enable = true,
				-- 关闭 vim 自带语法高亮引擎，只使用 Treesitter
				additional_vim_regex_highlighting = false,
			},
			incremental_selection = {
				enable = true,
				keymaps = {
					init_selection = "<s-tab>",
					node_incremental = "<cr>",
					node_decremental = "<bs>",
					scope_incremental = "<tab>",
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
						["<a-.>"] = "@parameter.inner",
					},
					swap_previous = {
						["<a-,>"] = "@parameter.inner",
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

		--------------------------------------------------------------------------------
		-- Treesitter Repeatable Move 统一跳转重复系统
		-- 让所有跳转都能用 ; 重复、, 反向重复
		--------------------------------------------------------------------------------

		local ts_repeat_move = require("nvim-treesitter.textobjects.repeatable_move")

		--------------------------------------------------------------------------------
		-- 1. 基础重复：让 ; 和 , 固定为向前 / 向后重复跳转
		--------------------------------------------------------------------------------

		-- ; 永远向前重复上一次跳转
		-- , 永远向后重复上一次跳转
		vim.keymap.set({ "n", "x", "o" }, ";", ts_repeat_move.repeat_last_move_next)
		vim.keymap.set({ "n", "x", "o" }, ",", ts_repeat_move.repeat_last_move_previous)

		--------------------------------------------------------------------------------
		-- 2. Vim 内置 f/F/t/T 也接入 repeat 系统
		--------------------------------------------------------------------------------

		-- 使用 expr = true 替换 f/F/t/T 的原始行为
		vim.keymap.set({ "n", "x", "o" }, "f", ts_repeat_move.builtin_f_expr, { expr = true })
		vim.keymap.set({ "n", "x", "o" }, "F", ts_repeat_move.builtin_F_expr, { expr = true })
		vim.keymap.set({ "n", "x", "o" }, "t", ts_repeat_move.builtin_t_expr, { expr = true })
		vim.keymap.set({ "n", "x", "o" }, "T", ts_repeat_move.builtin_T_expr, { expr = true })

		--------------------------------------------------------------------------------
		-- 3. 自定义 repeat 例子（可选）
		-- <Home>: 反向重复上次跳转 + 移动到目标开头
		-- <End>:  正向重复上次跳转 + 移动到目标末尾
		--------------------------------------------------------------------------------

		vim.keymap.set({ "n", "x", "o" }, "<Home>", function()
			ts_repeat_move.repeat_last_move({ forward = false, start = true })
		end)

		vim.keymap.set({ "n", "x", "o" }, "<End>", function()
			ts_repeat_move.repeat_last_move({ forward = true, start = false })
		end)

		--------------------------------------------------------------------------------
		-- 4. 让其他插件（例如 gitsigns）也变成可重复跳转的动作
		-- 例如：]h / [h 跳到下一个 / 上一个 hunk
		--------------------------------------------------------------------------------

		local ok, gs = pcall(require, "gitsigns")
		if ok then
			-- 创建 repeatable 跳转函数组合
			local next_hunk_repeat, prev_hunk_repeat =
				ts_repeat_move.make_repeatable_move_pair(gs.next_hunk, gs.prev_hunk)

			-- 覆盖 ]h 和 [h，使它们支持 ; 和 , 重复
			vim.keymap.set({ "n", "x", "o" }, "]h", next_hunk_repeat)
			vim.keymap.set({ "n", "x", "o" }, "[h", prev_hunk_repeat)
		end
	end,
}
