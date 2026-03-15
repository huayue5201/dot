-- https://github.com/huayue5201/nvim-translator

return {
	"huayue5201/nvim-translator",
	dir = "~/nvim-translator",
	dev = true,
	event = "VeryLazy",

	opts = {
		target_lang = "zh",
		source_lang = "auto",
		default_engines = { "google", "bing" },
		window_type = "float", -- Neovim 不支持 popup，float 才是正确的
		history_enable = true,
	},

	config = function(_, opts)
		-- 写入全局配置（插件内部依赖 vim.g）
		vim.g.translator_target_lang = opts.target_lang
		vim.g.translator_source_lang = opts.source_lang
		vim.g.translator_default_engines = opts.default_engines
		vim.g.translator_window_type = opts.window_type
		vim.g.translator_history_enable = opts.history_enable

		-- 需要 util
		local util = require("translator.util")

		vim.schedule(function()
			local ok, translator = pcall(require, "translator")
			if not ok then
				vim.notify("translator.nvim not loaded", vim.log.levels.ERROR)
				return
			end

			----------------------------------------------------------------------
			-- 普通模式：翻译当前光标词
			----------------------------------------------------------------------
			vim.keymap.set("n", "<Leader>tle", function()
				translator.start("echo", false, 0, 1, 1, vim.fn.expand("<cword>"))
			end, { silent = true, desc = "翻译并回显（当前词）" })

			vim.keymap.set("n", "<Leader>tlw", function()
				translator.start("window", false, 0, 1, 1, vim.fn.expand("<cword>"))
			end, { silent = true, desc = "翻译并窗口显示（当前词）" })

			vim.keymap.set("n", "<Leader>tlr", function()
				vim.cmd("normal! viw")
				local text = util.visual_select(2, 1, 1)
				translator.start("replace", false, 2, 1, 1, text)
			end, { silent = true, desc = "翻译并替换（当前词）" })

			vim.keymap.set("n", "<Leader>tlx", function()
				translator.start("echo", false, 0, 1, 1, vim.fn.getreg("*"))
			end, { silent = true, desc = "翻译剪贴板" })

			----------------------------------------------------------------------
			-- 可视模式：翻译选中文本
			----------------------------------------------------------------------
			vim.keymap.set("v", "<Leader>tle", function()
				local text = util.visual_select(2, 1, 1)
				translator.start("echo", false, 2, 1, 1, text)
			end, { silent = true, desc = "翻译并回显（选区）" })

			vim.keymap.set("v", "<Leader>tlw", function()
				local text = util.visual_select(2, 1, 1)
				translator.start("window", false, 2, 1, 1, text)
			end, { silent = true, desc = "翻译并窗口显示（选区）" })

			vim.keymap.set("v", "<Leader>tlr", function()
				local text = util.visual_select(2, 1, 1)
				translator.start("replace", false, 2, 1, 1, text)
			end, { silent = true, desc = "翻译并替换（选区）" })

			----------------------------------------------------------------------
			-- 浮窗滚动（仅 float 模式有效）
			----------------------------------------------------------------------
			vim.keymap.set("n", "<M-f>", function()
				local float = require("translator.window.float")
				if float.has_scroll() then
					float.scroll(true, 1)
				else
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<M-f>", true, false, true), "n", false)
				end
			end, { desc = "翻译窗口向下滚动" })

			vim.keymap.set("n", "<M-b>", function()
				local float = require("translator.window.float")
				if float.has_scroll() then
					float.scroll(false, 1)
				else
					vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<M-b>", true, false, true), "n", false)
				end
			end, { desc = "翻译窗口向上滚动" })

			----------------------------------------------------------------------
			-- 历史与日志
			----------------------------------------------------------------------
			vim.keymap.set("n", "<Leader>tlh", "<Cmd>TranslateH<CR>", { silent = true, desc = "翻译历史" })
			vim.keymap.set("n", "<Leader>tll", "<Cmd>TranslateL<CR>", { silent = true, desc = "翻译日志" })
		end)
	end,
}
