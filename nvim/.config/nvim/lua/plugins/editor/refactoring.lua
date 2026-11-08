-- https://github.com/ThePrimeagen/refactoring.nvim
--
-- 基于 treesitter 的重构 operator：提取函数/变量、内联变量/函数。
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
-- ⚠️ 语言约束：插件只附带 16 种语言的 refactor_* queries（c/cpp/c_sharp/go/java/ecma/
-- javascript/kotlin/lua/php/powershell/python/ruby/tsx/typescript/vim），其它语言
-- （Rust、Zig、Elixir…）一按就抛 "There is no `refactor_xxx` query file for language <lang>"。
-- 所以这里按 buffer 的 treesitter 语言探测 query，**只在支持的 buffer 里建映射**：
-- 不支持的语言（如 Rust）压根没有这些键位，which-key 里也不会出现，属于视觉噪音的就不给。
-- Rust 的重构走 rust-analyzer 的 code action（`gra`，见 lua/plugins/lsp/tiny-code-action.lua）。
--
-- 各操作实际依赖的 query（读插件源码得到，非猜测）：
--   extract_func:        extract_func.lua:95 output_function + :262 reference + :264 scope
--   extract_func_to_file 额外用 extract_func.lua:147 input_function
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

-- 按依赖顺序列出（key / 插件函数名 / 注释）
local OPS = {
	{ key = "e", name = "extract_func", desc = "重构: 提取函数" },
	{ key = "E", name = "extract_func_to_file", desc = "重构: 提取函数到新文件" },
	{ key = "v", name = "extract_var", desc = "重构: 提取变量" },
	{ key = "i", name = "inline_var", desc = "重构: 内联变量" },
	{ key = "I", name = "inline_func", desc = "重构: 内联函数" },
	{ key = "s", name = "select_refactor", desc = "重构: 选择要执行的重构" },
}

return {
	"ThePrimeagen/refactoring.nvim",
	config = function()
		-- setup() 不是必须的（默认配置即可用），显式调用便于以后覆盖 config.lua 的字段
		require("refactoring").setup({})

		-- 必须拿到真实 parser：插件 queries 里虽然有某种语言的 query 文件，
		-- 但该语言的 parser 未必装了（如 cpp/java），那种情况下注册了键位也会在
		-- 按下时抛 "no parser for 'cpp' language"。所以拿不到 parser 就不注册。
		local function buf_lang(buf)
			local ok, parser = pcall(vim.treesitter.get_parser, buf)
			if not ok or not parser then
				return nil
			end
			return parser:lang()
		end

		local function has_queries(op_name, lang)
			for _, q in ipairs(REQUIRED[op_name] or {}) do
				if not vim.treesitter.query.get(lang, q) then
					return false
				end
			end
			return true
		end
		-- 为单个 buffer 安装它支持的那几个键位（buffer-local，别的 buffer 不受影响）
		local function install(buf)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			local lang = buf_lang(buf)
			if not lang then
				return
			end
			for _, op in ipairs(OPS) do
				local lhs = "<leader>r" .. op.key
				-- FileType 会重复触发：先清掉本 buffer 上可能残留的旧映射
				pcall(vim.keymap.del, { "n", "x" }, lhs, { buffer = buf })
				if has_queries(op.name, lang) then
					vim.keymap.set({ "n", "x" }, lhs, function()
						return require("refactoring")[op.name]()
					end, { expr = true, buffer = buf, desc = op.desc })
				end
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("refactoring_lang_guard", { clear = true }),
			callback = function(event)
				install(event.buf)
			end,
		})

		-- 插件可能在已有 buffer 之后才加载（vim.pack 是启动时加载，但保险起见）
		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				install(buf)
			end
		end
	end,
}
