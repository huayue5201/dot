-- https://github.com/windwp/nvim-autopairs

return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	config = function()
		local npairs = require("nvim-autopairs")
		local Rule = require("nvim-autopairs.rule")
		local ts_conds = require("nvim-autopairs.ts-conds")

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

		-- press % => %% only while inside a comment or string
		npairs.add_rules({
			Rule("%", "%", "lua"):with_pair(ts_conds.is_ts_node({ "string", "comment" })),
			Rule("$", "$", "lua"):with_pair(ts_conds.is_not_ts_node({ "function" })),
		})

		-- 可以跳过, ;
		for _, punct in pairs({ ",", ";" }) do
			require("nvim-autopairs").add_rules({
				require("nvim-autopairs.rule")("", punct)
					:with_move(function(opts)
						return opts.char == punct
					end)
					:with_pair(function()
						return false
					end)
					:with_del(function()
						return false
					end)
					:with_cr(function()
						return false
					end)
					:use_key(punct),
			})
		end
	end,
}
