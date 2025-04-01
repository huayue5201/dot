-- https://github.com/huayue5201/vim-translator
-- https://github.com/voldikss/vim-translator

return {
	"huayue5201/vim-translator",
	keys = {
		{ "<Leader>tle", desc = "翻译并在命令行回显" },
		{ "<Leader>tle", desc = "翻译选中的文本并在命令行回显" },
		{ "<Leader>tlw", desc = "翻译并在窗口中显示" },
		{ "<Leader>tlw", desc = "翻译选中的文本并在窗口中显示" },
		{ "<Leader>tlr", desc = "用翻译替换文本" },
		{ "<Leader>tlr", desc = "用翻译替换选中的文本" },
		{ "<Leader>tlx", desc = "翻译剪贴板中的文本" },
	},
	config = function()
		vim.keymap.set("n", "<Leader>tle", "<Plug>Translate", { silent = true, desc = "在命令行回显翻译" })
		vim.keymap.set(
			"v",
			"<Leader>tle",
			"<Plug>TranslateV",
			{ silent = true, desc = "在命令行回显翻译（可视模式）" }
		)

		vim.keymap.set("n", "<Leader>tlw", "<Plug>TranslateW", { silent = true, desc = "在窗口中显示翻译" })
		vim.keymap.set(
			"v",
			"<Leader>tlw",
			"<Plug>TranslateWV",
			{ silent = true, desc = "在窗口中显示翻译（可视模式）" }
		)

		vim.keymap.set("n", "<Leader>tlr", "<Plug>TranslateR", { silent = true, desc = "用翻译替换文本" })
		vim.keymap.set(
			"v",
			"<Leader>tlr",
			"<Plug>TranslateRV",
			{ silent = true, desc = "用翻译替换文本（可视模式）" }
		)

		vim.keymap.set("n", "<Leader>tlx", "<Plug>TranslateX", { silent = true, desc = "翻译剪贴板中的文本" })

		-- 处理浮动窗口滚动的映射
		vim.keymap.set("n", "<M-f>", function()
			if
				vim.fn.exists("*translator#window#float#has_scroll") == 1
				and vim.fn["translator#window#float#has_scroll"]()
			then
				return vim.fn
			else
				return "<M-f>"
			end
		end, { expr = true, silent = true, desc = "向下滚动翻译窗口" })

		vim.keymap.set("n", "<M-b>", function()
			if
				vim.fn.exists("*translator#window#float#has_scroll") == 1
				and vim.fn["translator#window#float#has_scroll"]()
			then
				return vim.fn
			else
				return "<M-b>"
			end
		end, { expr = true, silent = true, desc = "向上滚动翻译窗口" })
	end,
}
