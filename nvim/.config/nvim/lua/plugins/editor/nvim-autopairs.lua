-- https://github.com/windwp/nvim-autopairs
-- 取代 ultimate-autopair：配对能力相近但每键开销与文件大小无关（ultimate 在 2000 行文件里约 7ms/键）。
-- 无法无损迁移的部分：命令行模式配对、跨行（multiline）配对、per-pair 的 space 展开。
-- 命令行配对如需保留，只能另找插件（nvim-autopairs 没有 c 模式映射）。

return {
	"windwp/nvim-autopairs",
	config = function()
		local npairs = require("nvim-autopairs")
		local Rule = require("nvim-autopairs.rule")

		npairs.setup({
			map_bs = true, -- <BS> 智能删除空配对
			map_cr = true, -- <CR> 在 {|} 里换行/自动补闭括号
			map_c_h = false,
			map_c_w = false,
			enable_moveright = true, -- 右侧已是闭括号时直接跳过（ultimate 的 fly/fly.other_char=" " 效果）
			enable_check_bracket_line = true,
			enable_bracket_in_quote = true,
			enable_afterquote = false, -- 引号后不配对，避免 ''' 之类误触发
			enable_abbr = false,
			break_undo = true,
			disable_in_macro = true,
			disable_in_replace_mode = true,
			disable_in_visualblock = false,
			ignored_next_char = [=[[%w%%%'%[%"%.%`%$]]=],
			disable_filetype = {
				"TelescopePrompt",
				"spectre_panel",
				"snacks_picker_input",
				"neo-tree",
				"qf",
				"help",
			},
			check_ts = true, -- 注释/字符串里不配对（ultimate 的 tsnode 扩展）
			ts_config = {
				lua = { "string", "comment", "string_content" },
				javascript = { "string", "template_string", "comment" },
				javascriptreact = { "string", "template_string", "comment" },
				typescript = { "string", "template_string", "comment" },
				typescriptreact = { "string", "template_string", "comment" },
				python = { "string", "comment" },
				rust = { "string_literal", "raw_string_literal", "line_comment", "block_comment" },
				go = { "interpreted_string_literal", "raw_string_literal", "comment" },
				c = { "string_literal", "char_literal", "comment" },
				cpp = { "string_literal", "char_literal", "comment" },
				json = { "string" },
				yaml = { "string_scalar", "comment" },
				bash = { "string", "raw_string", "comment" },
				vim = { "string", "comment" },
			},
			-- ultimate 的 fastwarp：先按 <A-e>，再敲要包裹的括号，跳到最近的闭括号/引号
			fast_wrap = {
				map = "<A-e>",
				chars = { "{", "[", "(", '"', "'", "`" },
				pattern = [=[[%'%"%>%]%)%}%,%`]]=],
				highlight = "IncSearch",
				highlight_grey = "Comment",
			},
		})

		npairs.add_rules({
			-- JSX/TSX 的 <Tag>：只在标记/组件文件里配对
			Rule("<", ">", { "javascriptreact", "typescriptreact", "vue", "svelte" }),

			-- 多字符配对（对应 ultimate 里 internal_pairs 的 ft 限定项）
			Rule("<!--", "-->", { "html", "xml", "markdown" }),
			Rule("```", "```", { "markdown" }),
			Rule('"""', '"""', { "python" }),
			Rule("'''", "'''", { "python" }),
			Rule("$$", "$$", { "tex", "latex", "markdown" }),
			Rule('r#"', '"#', { "rust" }),

			-- 中文输入法常见全角标点也成对（不转换，只补全）
			Rule("（", "）"),
			Rule("【", "】"),
			Rule("“", "”"),
			Rule("‘", "’"),
		})

		-- ultimate 的 tabout：<C-l> 右侧是闭括号/引号时向右跳出一格；否则不动作
		local closing = { [")"] = true, ["]"] = true, ["}"] = true, ['"'] = true, ["'"] = true, ["`"] = true }
		vim.keymap.set("i", "<C-l>", function()
			local col = vim.fn.col(".")
			if closing[vim.api.nvim_get_current_line():sub(col, col)] then
				return "<Right>"
			end
			return ""
		end, { expr = true, replace_keycodes = true, desc = "autopairs: 跳出配对" })
	end,
}
