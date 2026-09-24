-- https://github.com/huayue5201/nvim-translator
return {
	"huayue5201/nvim-translator",
	dir = "~/neovim-plugins/nvim-translator",
	dev = true,
	event = "VeryLazy",
	build = "make build", -- 确保后端二进制是最新构建

	config = function()
		----------------------------------------------------------------------
		-- 基础配置（插件内部依赖 vim.g）
		----------------------------------------------------------------------
		vim.g.translator_target_lang = "zh"
		vim.g.translator_source_lang = "auto"
		vim.g.translator_window_type = "float" -- "float" | "preview"
		vim.g.translator_history_enable = true
		vim.g.translator_proxy_url = "" -- 需要代理时填，如 "socks5://127.0.0.1:1080"

		----------------------------------------------------------------------
		-- LLM 引擎（DeepSeek）
		----------------------------------------------------------------------
		vim.g.translator_target_lang = "zh"
		vim.g.translator_source_lang = "auto"
		vim.g.translator_window_type = "float"
		vim.g.translator_history_enable = true

		vim.g.translator_llm = {
			name = "deepseek",
			env = {
				api_key = function()
					return os.getenv("DEEPSEEK_API_KEY")
				end,
			},
			schema = {
				model = {
					default = "deepseek-chat",
				},
			},
		}

		-- 想混合免费引擎做 fallback 可以改成：
		vim.g.translator_default_engines = { "llm", "google", "baidu", "bing" }

		----------------------------------------------------------------------
		-- Keymap
		----------------------------------------------------------------------
		local util = require("translator.util")
		local translator = require("translator")

		-- 普通模式：翻译当前词（回显）
		vim.keymap.set("n", "<localLeader>tle", function()
			translator.start("echo", false, 0, 1, 1, vim.fn.expand("<cword>"))
		end, { silent = true, desc = "翻译并回显（当前词）" })

		-- 普通模式：翻译当前句（回显）
		vim.keymap.set("n", "<localLeader>tls", function()
			vim.cmd("normal! vis")
			local text = util.visual_select(2, 1, 1)
			translator.start("echo", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并回显（当前句）" })

		-- 窗口显示（普通模式：当前词）
		vim.keymap.set("n", "<C-;>", function()
			translator.start("window", false, 0, 1, 1, vim.fn.expand("<cword>"))
		end, { silent = true, desc = "翻译并窗口显示（当前词）" })

		-- 替换当前词
		vim.keymap.set("n", "<localLeader>tlr", function()
			vim.cmd("normal! viw")
			local text = util.visual_select(2, 1, 1)
			translator.start("replace", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并替换（当前词）" })

		-- 翻译剪贴板（* 寄存器）
		vim.keymap.set("n", "<localLeader>tlx", function()
			translator.start("echo", false, 0, 1, 1, vim.fn.getreg("*"))
		end, { silent = true, desc = "翻译剪贴板" })

		vim.keymap.set("n", "<localLeader>tls", "<Cmd>TranslateSay<CR>", { desc = "读原文" })
		vim.keymap.set("n", "<localLeader>tlt", "<Cmd>TranslateSay!<CR>", { desc = "读译文" })
		vim.keymap.set("n", "<localLeader>tla", "<Cmd>TranslateA<CR>", { desc = "加入 Anki" })
		----------------------------------------------------------------------
		-- 可视模式：翻译选中文本（支持句子/段落）
		----------------------------------------------------------------------
		vim.keymap.set("v", "<localLeader>tle", function()
			local text = util.visual_select(2, 1, 1)
			translator.start("echo", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并回显（选区）" })

		vim.keymap.set("v", "<C-;>", function()
			local text = util.visual_select(2, 1, 1)
			translator.start("window", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并窗口显示（选区）" })

		vim.keymap.set("v", "<localLeader>tlr", function()
			local text = util.visual_select(2, 1, 1)
			translator.start("replace", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并替换（选区）" })

		----------------------------------------------------------------------
		-- 浮窗滚动
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
		vim.keymap.set("n", "<localLeader>tlh", "<Cmd>TranslateH<CR>", { silent = true, desc = "翻译历史" })
		vim.keymap.set("n", "<localLeader>tll", "<Cmd>TranslateL<CR>", { silent = true, desc = "翻译日志" })
	end,
}
