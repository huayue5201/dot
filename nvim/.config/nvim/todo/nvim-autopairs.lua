-- https://github.com/windwp/nvim-autopairs

return {
	"windwp/nvim-autopairs",
	event = "InsertEnter", -- 插入模式进入时加载插件
	config = function()
		-- 引入 nvim-autopairs 插件和相关模块
		local npairs = require("nvim-autopairs")
		local Rule = require("nvim-autopairs.rule") -- 用于定义配对规则
		local cond = require("nvim-autopairs.conds") -- 用于定义条件
		local ts_conds = require("nvim-autopairs.ts-conds") -- 用于 Treesitter 条件

		-- 配置 nvim-autopairs 插件
		npairs.setup({
			fast_wrap = {}, -- 配置快速包裹（可选）
			check_ts = true, -- 启用 Treesitter 检查
			ts_config = {
				lua = { "string" }, -- 在 Lua 中，忽略字符串内的配对
				javascript = { "template_string" }, -- 在 JavaScript 中，忽略模板字符串的配对
				java = false, -- 不检查 Java 文件
			},
			enabled = function(bufnr) -- 控制是否启用自动配对
				return true
			end,
			disable_filetype = { "TelescopePrompt", "spectre_panel", "snacks_picker_input" }, -- 禁用文件类型
			disable_in_macro = true, -- 录制宏时禁用
			disable_in_visualblock = false, -- 可视块模式下启用
			disable_in_replace_mode = true, -- 替换模式下禁用
			ignored_next_char = [=[[%w%%%'%[%"%.%`%$]]=], -- 在这些字符后面不自动添加配对符号
			enable_moveright = true, -- 启用右移时的自动配对
			enable_afterquote = true, -- 在引号后面添加配对符号
			enable_check_bracket_line = true, -- 检查括号是否在同一行
			enable_bracket_in_quote = true, -- 在引号内自动配对括号
			enable_abbr = false, -- 禁用缩写触发自动配对
			break_undo = true, -- 启用基础规则时的撤销中断
			map_cr = true, -- 回车键映射，触发自动配对
			map_bs = true, -- 退格键映射，删除配对符号
			map_c_h = false, -- 不将 <C-h> 映射为删除配对符号
			map_c_w = false, -- 不将 <C-w> 映射为删除配对符号
		})

		local function rule2(a1, ins, a2, lang)
			npairs.add_rule(Rule(ins, ins, lang)
				:with_pair(function(opts)
					return a1 .. a2 == opts.line:sub(opts.col - #a1, opts.col + #a2 - 1)
				end)
				:with_move(cond.none())
				:with_cr(cond.none())
				:with_del(function(opts)
					local col = vim.api.nvim_win_get_cursor(0)[2]
					return a1 .. ins .. ins .. a2 == opts.line:sub(col - #a1 - #ins + 1, col + #ins + #a2) -- insert only works for #ins == 1 anyway
				end))
		end

		rule2("(", "*", ")", "ocaml")
		rule2("(*", " ", "*)", "ocaml")
		rule2("(", " ", ")")

		local brackets = { { "(", ")" }, { "[", "]" }, { "{", "}" } }

		-- For each pair of brackets we will add another rule
		for _, bracket in pairs(brackets) do
			npairs.add_rules({
				-- Rule for a pair with left-side ' ' and right side ' '
				Rule(" ", " ")
					-- Pair will only occur if the conditional function returns true
					:with_pair(function(opts)
						-- We are checking if we are inserting a space in (), [], or {}
						local pair = opts.line:sub(opts.col - 1, opts.col)
						return vim.tbl_contains({
							brackets[1][1] .. brackets[1][2],
							brackets[2][1] .. brackets[2][2],
							brackets[3][1] .. brackets[3][2],
						}, pair)
					end)
					:with_move(cond.none())
					:with_cr(cond.none())
					-- We only want to delete the pair of spaces when the cursor is as such: ( | )
					:with_del(
						function(opts)
							local col = vim.api.nvim_win_get_cursor(0)[2]
							local context = opts.line:sub(col - 1, col + 2)
							return vim.tbl_contains({
								brackets[1][1] .. "  " .. brackets[1][2],
								brackets[2][1] .. "  " .. brackets[2][2],
								brackets[3][1] .. "  " .. brackets[3][2],
							}, context)
						end
					),

				-- Each of these rules is for a pair with left-side '( ' and right-side ' )' for each bracket type
				Rule(bracket[1] .. " ", " " .. bracket[2])
					:with_pair(cond.none())
					:with_move(function(opts)
						return opts.char == bracket[2]
					end)
					:with_del(cond.none())
					:use_key(bracket[2])
					-- Removes the trailing whitespace that can occur without this
					:replace_map_cr(function(_)
						return "<C-c>2xi<CR><C-c>O"
					end),

				-- 范型支持
				Rule("<", ">", {
					-- if you use nvim-ts-autotag, you may want to exclude these filetypes from this rule
					-- so that it doesn't conflict with nvim-ts-autotag
					"-html",
					"-javascriptreact",
					"-typescriptreact",
				}):with_pair(
					-- regex will make it so that it will auto-pair on
					-- `a<` but not `a <`
					-- The `:?:?` part makes it also
					-- work on Rust generics like `some_func::<T>()`
					cond.before_regex("%a+:?:?$", 3)
				):with_move(function(opts)
					return opts.char == ">"
				end),

				-- 自动格式化=
				Rule("=", "")
					:with_pair(cond.not_inside_quote())
					:with_pair(function(opts)
						local last_char = opts.line:sub(opts.col - 1, opts.col - 1)
						if last_char:match("[%w%=%s]") then
							return true
						end
						return false
					end)
					:replace_endpair(function(opts)
						local prev_2char = opts.line:sub(opts.col - 2, opts.col - 1)
						local next_char = opts.line:sub(opts.col, opts.col)
						next_char = next_char == " " and "" or " "
						if prev_2char:match("%w$") then
							return "<bs> =" .. next_char
						end
						if prev_2char:match("%=$") then
							return next_char
						end
						if prev_2char:match("=") then
							return "<bs><bs>=" .. next_char
						end
						return ""
					end)
					:set_end_pair_length(0)
					:with_move(cond.none())
					:with_del(cond.none()),

				-- 在Lua表中为"'}添加尾随逗号
				Rule("{", "},", "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
				Rule("'", "',", "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
				Rule('"', '",', "lua"):with_pair(ts_conds.is_ts_node({ "table_constructor" })),
			})
		end
	end,
}
