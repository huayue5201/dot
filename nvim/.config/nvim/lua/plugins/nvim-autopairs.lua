-- https://github.com/windwp/nvim-autopairs

return {
	"windwp/nvim-autopairs",
	event = "InsertEnter",
	dependencies = "hrsh7th/nvim-cmp",
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

		-- cmp集成
		local cmp = require("cmp")
		local cmp_autopairs = require("nvim-autopairs.completion.cmp")
		local ts_utils = require("nvim-treesitter.ts_utils")

		local ts_node_func_parens_disabled = {
			-- ecma
			named_imports = true,
			-- rust
			use_declaration = true,
		}

		local default_handler = cmp_autopairs.filetypes["*"]["("].handler
		cmp_autopairs.filetypes["*"]["("].handler = function(char, item, bufnr, rules, commit_character)
			local node_type = ts_utils.get_node_at_cursor():type()
			if ts_node_func_parens_disabled[node_type] then
				if item.data then
					item.data.funcParensDisabled = true
				else
					char = ""
				end
			end
			default_handler(char, item, bufnr, rules, commit_character)
		end

		cmp.event:on(
			"confirm_done",
			cmp_autopairs.on_confirm_done({
				sh = false,
			})
		)
	end,
}
