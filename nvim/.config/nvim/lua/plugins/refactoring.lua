-- https://github.com/ThePrimeagen/refactoring.nvim

return {
	"ThePrimeagen/refactoring.nvim",
	lazy = false,
	config = function()
		require("refactoring").setup({})

		local keymap = vim.keymap

		-- ============ 重构功能 ============
		-- 提取函数
		keymap.set({ "n", "x" }, "<leader>re", function()
			return require("refactoring").extract_func()
		end, { desc = "提取函数", expr = true })
		-- `_` 是默认的"当前行"文本对象
		keymap.set("n", "<leader>ree", function()
			return require("refactoring").extract_func() .. "_"
		end, { desc = "提取函数（当前行）", expr = true })

		-- 提取函数到文件
		keymap.set({ "n", "x" }, "<leader>rE", function()
			return require("refactoring").extract_func_to_file()
		end, { desc = "提取函数到文件", expr = true })

		-- 提取变量
		keymap.set({ "n", "x" }, "<leader>rv", function()
			return require("refactoring").extract_var()
		end, { desc = "提取变量", expr = true })
		-- `_` 是默认的"当前行"文本对象
		keymap.set("n", "<leader>rvv", function()
			return require("refactoring").extract_var() .. "_"
		end, { desc = "提取变量（当前行）", expr = true })

		-- 内联变量
		keymap.set({ "n", "x" }, "<leader>ri", function()
			return require("refactoring").inline_var()
		end, { desc = "内联变量", expr = true })

		-- 内联函数
		keymap.set({ "n", "x" }, "<leader>rI", function()
			return require("refactoring").inline_func()
		end, { desc = "内联函数", expr = true })

		-- 选择重构操作
		keymap.set({ "n", "x" }, "<leader>rs", function()
			return require("refactoring").select_refactor()
		end, { desc = "选择重构操作", expr = true })

		-- ============ 调试打印功能（前缀改为 rp） ============
		-- 打印变量（下方）- `iw` 是内置的"单词内"文本对象
		keymap.set("n", "<leader>rpv", function()
			return require("refactoring.debug").print_var({ output_location = "below" }) .. "iw"
		end, { desc = "调试打印变量（下方）", expr = true })
		keymap.set("x", "<leader>rpv", function()
			return require("refactoring.debug").print_var({ output_location = "below" })
		end, { desc = "调试打印变量（下方）", expr = true })

		-- 打印变量（上方）
		keymap.set("n", "<leader>rpV", function()
			return require("refactoring.debug").print_var({ output_location = "above" }) .. "iw"
		end, { desc = "调试打印变量（上方）", expr = true })
		keymap.set("x", "<leader>rpV", function()
			return require("refactoring.debug").print_var({ output_location = "above" })
		end, { desc = "调试打印变量（上方）", expr = true })

		-- 打印表达式（下方）
		keymap.set({ "x", "n" }, "<leader>rpe", function()
			return require("refactoring.debug").print_exp({ output_location = "below" })
		end, { desc = "调试打印表达式（下方）", expr = true })
		-- `_` 是默认的"当前行"文本对象
		keymap.set("n", "<leader>rpee", function()
			return require("refactoring.debug").print_exp({ output_location = "below" }) .. "_"
		end, { desc = "调试打印表达式（下方-当前行）", expr = true })

		-- 打印表达式（上方）
		keymap.set({ "x", "n" }, "<leader>rpE", function()
			return require("refactoring.debug").print_exp({ output_location = "above" })
		end, { desc = "调试打印表达式（上方）", expr = true })
		-- `_` 是默认的"当前行"文本对象
		keymap.set("n", "<leader>rpEE", function()
			return require("refactoring.debug").print_exp({ output_location = "above" }) .. "_"
		end, { desc = "调试打印表达式（上方-当前行）", expr = true })

		-- 打印位置（上方）
		keymap.set("n", "<leader>rpP", function()
			return require("refactoring.debug").print_loc({ output_location = "above" })
		end, { desc = "调试打印位置（上方）", expr = true })

		-- 打印位置（下方）
		keymap.set("n", "<leader>rpp", function()
			return require("refactoring.debug").print_loc({ output_location = "below" })
		end, { desc = "调试打印位置（下方）", expr = true })

		-- 清理调试打印
		keymap.set({ "x", "n" }, "<leader>rpc", function()
			-- 这个快捷键默认不选择任何文本对象，所以每次使用时需要自己提供
			return require("refactoring.debug").cleanup({ restore_view = true })
		end, { desc = "清理调试打印", expr = true, remap = true })
	end,
}
