-- https://github.com/windwp/nvim-autopairs

return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		local npairs = require("nvim-autopairs")
		local Rule = require("nvim-autopairs.rule")
		-- local ts_conds = require("nvim-autopairs.ts-conds")
		local cond = require("nvim-autopairs.conds")

		-- change default fast_wrap
		npairs.setup({
			fast_wrap = {
				map = "<M-e>",
				chars = { "{", "[", "(", '"', "'" },
				pattern = [=[[%'%"%>%]%)%}%,]]=],
				end_key = "$",
				before_key = "h",
				after_key = "l",
				cursor_pos_before = true,
				keys = "qwertyuiopzxcvbnmasdfghjkl",
				manual_position = true,
				highlight = "Search",
				highlight_grey = "Comment",
			},
			-- treesitter支持
			check_ts = true,
			ts_config = {
				lua = { "string" }, -- it will not add a pair on that treesitter node
				javascript = { "template_string" },
				java = false, -- don't check treesitter on java
			},
		})

		local brackets = { { "(", ")" }, { "[", "]" }, { "{", "}" } }
		-- press % => %% only while inside a comment or string
		npairs.add_rules({
			-- Rule("%", "%", "lua"):with_pair(ts_conds.is_ts_node({ "string", "comment" })),
			-- Rule("$", "$", "lua"):with_pair(ts_conds.is_not_ts_node({ "function" })),
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
			-- 泛型配对
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
		})
		-- For each pair of brackets we will add another rule
		for _, bracket in pairs(brackets) do
			npairs.add_rules({
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
			})
		end

		require("nvim-autopairs").get_rule("{"):replace_map_cr(function()
			local res = "<c-g>u<CR><CMD>normal! ====<CR><up><end><CR>"
			local line = vim.fn.winline()
			local height = vim.api.nvim_win_get_height(0)
			-- Check if current line is within [1/3, 2/3] of the screen height.
			-- If not, center the current line.
			if line < height / 3 or height * 2 / 3 < line then
				-- Here, 'x' is a placeholder to make sure the indentation doesn't break.
				res = res .. "x<ESC>zzs"
			end
			return res
		end)
	end,
}
