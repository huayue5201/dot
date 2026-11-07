-- https://github.com/ThePrimeagen/refactoring.nvim
--
-- 基于 treesitter + LSP 的重构operator：提取函数/变量、内联变量/函数。
-- 所有操作都是 vim operator（支持 . 重复、任意 textobject/motion），n/x 都可触发：
-- 可视模式对选区生效，普通模式下 `<leader>re` 之后跟一个 motion/textobject（如 `iw`、`_`、`ap`）。
--
-- 需要 Neovim >= 0.12.5（本机 0.13.0-dev），queries 已随插件打包，无需 async.nvim。
--
-- 只映射「重构」部分。debug print 系列（print_var / print_exp / cleanup）不映射：
-- 打印插入已由 nvim-chainsaw 的 `g?` 家族统一负责（见 lua/plugins/chainsaw.lua），
-- 两套同时上同一件事会互相打架。
--
-- 键位沿用 `<leader>r` 分组（重构 / 运行），字母遵循 README 的语义缩写：
--   e=extract function, v=extract variable, i=inline variable, I=inline function,
--   s=select（菜单里挑一个）, E=extract to file。

return {
	"ThePrimeagen/refactoring.nvim",
	config = function()
		-- setup() 不是必须的（默认配置即可用），显式调用便于以后覆盖 config.lua 的字段
		require("refactoring").setup({})

		local function op(fn, desc)
			vim.keymap.set({ "n", "x" }, "<leader>r" .. fn.key, function()
				return require("refactoring")[fn.name]()
			end, { expr = true, desc = desc })
		end

		op({ key = "e", name = "extract_func" }, "重构: 提取函数")
		op({ key = "E", name = "extract_func_to_file" }, "重构: 提取函数到新文件")
		op({ key = "v", name = "extract_var" }, "重构: 提取变量")
		op({ key = "i", name = "inline_var" }, "重构: 内联变量")
		op({ key = "I", name = "inline_func" }, "重构: 内联函数")

		vim.keymap.set({ "n", "x" }, "<leader>rs", function()
			require("refactoring").select_refactor()
		end, { desc = "重构: 选择要执行的重构" })
	end,
}
