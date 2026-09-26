-- https://github.com/huayue5201/nvim-translator

return {
	"huayue5201/nvim-translator",
	dir = "~/neovim-plugins/nvim-translator",
	dev = true,
	event = "VeryLazy",
	build = "make build", -- 确保后端二进制是最新构建
	config = function()
		----------------------------------------------------------------------
		-- 基础配置
		----------------------------------------------------------------------
		vim.g.translator_window_type = "float" -- "float" | "preview"
		vim.g.translator_history_enable = true
		vim.g.translator_proxy_url = "" -- 需要代理时填 "socks5://127.0.0.1:1080"
		-- 双语互翻自动检测方向，无需配置 target_lang / source_lang

		----------------------------------------------------------------------
		-- LLM 引擎（DeepSeek）
		----------------------------------------------------------------------
		vim.g.translator_llm = {
			name = "deepseek",
			env = {
				api_key = function()
					return os.getenv("DEEPSEEK_API_KEY")
				end,
			},
			schema = {
				model = { default = "deepseek-chat" },
			},
		}
		vim.g.translator_default_engines = { "llm", "google", "baidu", "bing" }

		----------------------------------------------------------------------
		-- Keymap
		----------------------------------------------------------------------
		local util = require("translator.util")
		local translator = require("translator")

		-- 普通模式：翻译当前词（回显）
		vim.keymap.set("n", "<localLeader>te", function()
			translator.start("echo", false, 0, 1, 1, vim.fn.expand("<cword>"))
		end, { silent = true, desc = "翻译并回显（当前词）" })

		-- 普通模式：翻译当前句（回显）—— key 改为 tlE，避免与"读原文"冲突
		vim.keymap.set("n", "<localLeader>tE", function()
			vim.cmd("normal! vis")
			local text = util.get_visual_selection()
			translator.start("echo", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并回显（当前句）" })

		-- 窗口显示（当前词）
		vim.keymap.set("n", "<leader>te", function()
			translator.start("window", false, 0, 1, 1, vim.fn.expand("<cword>"))
		end, { silent = true, desc = "翻译并窗口显示（当前词）" })

		vim.keymap.set("n", "<leader>ti", "<Cmd>TranslateI<CR>", { desc = "交互翻译" })

		-- API 文档翻译（面向代码符号，需配置 translator_llm）
		vim.keymap.set("n", "<localLeader>td", "<Cmd>TranslateApi<CR>", { desc = "API 文档翻译" })
		vim.keymap.set("v", "<localLeader>td", ":TranslateApi<CR>", { desc = "API 文档翻译" })

		-- 替换当前词
		vim.keymap.set("n", "<localLeader>tr", function()
			vim.cmd("normal! viw")
			local text = util.get_visual_selection()
			translator.start("replace", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并替换（当前词）" })

		-- 翻译剪贴板
		vim.keymap.set("n", "<localLeader>tx", function()
			translator.start("echo", false, 0, 1, 1, vim.fn.getreg("*"))
		end, { silent = true, desc = "翻译剪贴板" })

		-- 二级操作（也可在翻译浮窗 footer 里直接按 s/S/a/y/Esc）
		-- vim.keymap.set("n", "<localLeader>tls", "<Cmd>TranslateSay<CR>", { desc = "读原文" })
		-- vim.keymap.set("n", "<localLeader>tlt", "<Cmd>TranslateSay!<CR>", { desc = "读译文" })
		-- vim.keymap.set("n", "<localLeader>tla", "<Cmd>TranslateA<CR>", { desc = "加入 Anki" })

		----------------------------------------------------------------------
		-- 可视模式
		----------------------------------------------------------------------
		vim.keymap.set("v", "<localLeader>te", function()
			local text = util.get_visual_selection()
			translator.start("echo", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并回显（选区）" })

		vim.keymap.set("v", "<leader>te", function()
			local text = util.get_visual_selection()
			translator.start("window", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并窗口显示（选区）" })

		vim.keymap.set("v", "<localLeader>tr", function()
			local text = util.get_visual_selection()
			translator.start("replace", false, 2, 1, 1, text)
		end, { silent = true, desc = "翻译并替换（选区）" })

		----------------------------------------------------------------------
		-- 浮窗滚动
		----------------------------------------------------------------------
		vim.keymap.set("n", "<A-f>", function()
			local float = require("translator.window.float")
			if float.has_scroll() then
				float.scroll(true, 1)
			else
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<A-f>", true, false, true), "n", false)
			end
		end, { desc = "翻译窗口向下滚动" })

		vim.keymap.set("n", "<A-b>", function()
			local float = require("translator.window.float")
			if float.has_scroll() then
				float.scroll(false, 1)
			else
				vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<A-b>", true, false, true), "n", false)
			end
		end, { desc = "翻译窗口向上滚动" })

		----------------------------------------------------------------------
		-- 历史与日志
		----------------------------------------------------------------------
		vim.keymap.set("n", "<localLeader>th", "<Cmd>TranslateH<CR>", { silent = true, desc = "翻译历史" })
		vim.keymap.set("n", "<localLeader>tl", "<Cmd>TranslateL<CR>", { silent = true, desc = "翻译日志" })
	end,
}
