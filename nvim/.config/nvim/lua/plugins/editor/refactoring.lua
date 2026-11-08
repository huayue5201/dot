-- https://github.com/ThePrimeagen/refactoring.nvim
--
-- 基于 treesitter + LSP 的重构operator：提取函数/变量、内联变量/函数。
-- 所有操作都是 vim operator（支持 . 重复、任意 textobject/motion），n/x 都可触发：
-- 可视模式对选区生效，普通模式下 `<leader>re` 之后跟一个 motion/textobject（如 `iw`、`_`、`ap`）。
--
-- 需要 Neovim >= 0.12.5（本机 0.13.0-dev），queries 已随插件打包，无需 async.nvim。
--
-- 只映射「重构」部分。debug print 系列（print_var / print_exp / cleanup）不映射：
-- 打印插入已由 nvim-chainsaw 的 `g?` 家族统一负责（见 lua/plugins/editor/chainsaw.lua），
-- 两套同时上同一件事会互相打架。
--
-- 键位沿用 `<leader>r` 分组（重构 / 运行），字母遵循 README 的语义缩写：
--   e=extract function, v=extract variable, i=inline variable, I=inline function,
--   s=select（菜单里挑一个）, E=extract to file。
--
-- ⚠️ 语言约束：插件只附带 16 种语言的 queries（c/cpp/c_sharp/go/java/ecma/
-- javascript/kotlin/lua/php/powershell/python/ruby/tsx/typescript/vim），
-- 其它语言（Rust、Zig、Elixir…）一按就抛
-- "There is no `refactor_xxx` query file for language <lang>"。
-- 所以每次触发前先探 query 是否存在，缺了就只提示、不报错。
-- 各操作实际依赖的 query（读插件源码得到，非猜测）：
--   extract_func:        extract_func.lua:95 output_function + :262 reference + :264 scope
--   extract_var:         extract_var.lua:121 scope + :123 output_statement
--   inline_var:          inline_var.lua:88 reference + :90 variable
--   inline_func:         inline_func.lua:30 function + :32 function_call（**只有 lua 有**）
local REQUIRED = {
	extract_func = { "refactor_output_function", "refactor_reference", "refactor_scope" },
	extract_func_to_file = {
		"refactor_output_function",
		"refactor_reference",
		"refactor_scope",
		"refactor_input_function",
	},
	extract_var = { "refactor_scope", "refactor_output_statement" },
	inline_var = { "refactor_reference", "refactor_variable" },
	inline_func = { "refactor_function", "refactor_function_call" },
	-- 菜单本身不查 query，但它列出的操作都需要这组，缺了选哪个都会报错
	select_refactor = {
		"refactor_reference",
		"refactor_scope",
		"refactor_variable",
		"refactor_output_statement",
	},
}

return {
	"ThePrimeagen/refactoring.nvim",
	config = function()
		-- setup() 不是必须的（默认配置即可用），显式调用便于以后覆盖 config.lua 的字段
		require("refactoring").setup({})

		-- 与插件内部一致：用 buffer 的 treesitter parser 语言（不是 filetype），
		-- 这样 embedded 语言等情况判断才准。
		local function buf_lang(buf)
			local ok, parser = pcall(vim.treesitter.get_parser, buf)
			if not ok or not parser then
				return nil
			end
			return parser:lang()
		end

		-- 返回缺失的 query 名（nil = 全部具备）
		local function missing_query(op_name, lang)
			for _, q in ipairs(REQUIRED[op_name] or {}) do
				if not vim.treesitter.query.get(lang, q) then
					return q
				end
			end
			return nil
		end

		local function check(op_name, label)
			local lang = buf_lang(vim.api.nvim_get_current_buf())
			if not lang then
				vim.notify(
					("重构: %s 不可用——当前 buffer 没有 treesitter parser"):format(label),
					vim.log.levels.WARN
				)
				return false
			end
			local missing = missing_query(op_name, lang)
			if not missing then
				return true
			end
			local hint = lang == "rust" and "（Rust 用 `gra` 走 rust-analyzer 的 extract/inline code action）"
				or ""
			vim.notify(
				("重构: %s 在 %s 下不可用——缺少 queries/%s/%s.scm%s"):format(
					label,
					lang,
					lang,
					missing,
					hint
				),
				vim.log.levels.WARN
			)
			return false
		end

		local function op(fn, desc)
			local label = "重构: " .. desc
			vim.keymap.set({ "n", "x" }, "<leader>r" .. fn.key, function()
				if not check(fn.name, desc) then
					-- expr 映射必须返回字符串，返回 "" 表示不吞掉后续 motion
					return ""
				end
				return require("refactoring")[fn.name]()
			end, { expr = true, desc = label })
		end

		op({ key = "e", name = "extract_func" }, "提取函数")
		op({ key = "E", name = "extract_func_to_file" }, "提取函数到新文件")
		op({ key = "v", name = "extract_var" }, "提取变量")
		op({ key = "i", name = "inline_var" }, "内联变量")
		op({ key = "I", name = "inline_func" }, "内联函数")

		vim.keymap.set({ "n", "x" }, "<leader>rs", function()
			if not check("select_refactor", "选择要执行的重构") then
				return ""
			end
			require("refactoring").select_refactor()
		end, { expr = true, desc = "重构: 选择要执行的重构" })
	end,
}
