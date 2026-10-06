-- https://github.com/huayue5201/nvim-translator

return {
	"huayue5201/nvim-translator",
	dir = "~/neovim-plugins/nvim-translator",
	dev = true,
	build = "make build", -- 确保后端二进制是最新构建
	opts = {
		-- 语言方向：默认自动检测，一般无需设置
		source_lang = "auto",
		target_lang = "zh",
		bilingual = true,
		engines = { "llm", "google", "baidu", "bing" },
		request_timeout = 60000, -- 本地 LLM 推理较慢，放宽整体超时（默认 15s）
		proxy_url = "", -- 需要代理时填 "socks5://127.0.0.1:1080"
		llm = {
			-- 主端点：DeepSeek（在线，质量优先）
			name = "deepseek",
			env = {
				api_key = function()
					return os.getenv("DEEPSEEK_API_KEY")
				end,
			},
			schema = {
				model = { default = "deepseek-flash" },
			},
			-- 降级端点：本地 llama.cpp（断网时自动兜底）
			fallback = {
				base_url = "http://127.0.0.1:8080/v1",
				model = "qwen2.5-7b",
				prompt = [[You are a professional translation engine and dictionary. Translate the user's text from {sl} to {tl}.

Reply with ONLY a valid JSON object (no markdown fences, no commentary) in this exact shape:
{"paraphrase":"...","explains":["..."],"phonetic":"..."}

Rules:
- "paraphrase": the complete, natural translation of the user's text.
- "explains": detailed dictionary-style annotations as an array of strings. Each string describes a key word or phrase with part of speech and meaning, e.g. "quick (adj.) 快速的". For a single word, list its main senses as separate strings.
- "phonetic": pronunciation (IPA) of the SOURCE text. Use ONLY when the input is a single word; otherwise use "".
- Preserve meaning, tone, and line breaks faithfully.]],
			},
			-- 本地 llama-server 按需启动 + 空闲回收（配合 ~/models/llm-watchdog.sh + launchd 定时器）
			server = {
				cmd = {
					"/opt/homebrew/bin/llama-server",
					"-m",
					vim.fn.expand("~/models/qwen2.5-7b-instruct-q4_k_m-00001-of-00002.gguf"),
					"--alias",
					"qwen2.5-7b",
					"--host",
					"127.0.0.1",
					"--port",
					"8080",
					"-c",
					"8192",
				},
				health = "http://127.0.0.1:8080/health",
				wait = 120, -- 等待服务就绪的最长秒数
				poll_ms = 1000, -- 健康检查轮询间隔（毫秒）
				stamp = vim.fn.expand("~/.cache/translator/llm.last_active"),
			},
		},
		window = { type = "float" }, -- "float" | "preview"
		history = { enable = true },
		cache = {
			enable = true,
			ttl = 7 * 24 * 60 * 60, -- 7 天；0 = 永不过期
		},
		-- 面板高亮覆盖（克制风是默认值；需要时取消注释）
		-- highlights = {
		-- 	source = "Comment", -- 原文行 ⟦ … ⟧（false = 关闭）
		-- 	source_text = "Identifier", -- 被译对象本身
		-- 	engine = "Title", -- 引擎头
		-- 	phonetic = "Comment", -- 音标
		-- 	marker = "Special", -- 行首标记 • / ↳
		-- },
		-- anki = { deck = "翻译", port = 8765, model = "translator" },
		-- tts = { engine = "say" }, -- "say" | "google"
	},
	config = function(_, opts)
		require("translator").setup(opts)

		----------------------------------------------------------------------
		-- Keymap
		----------------------------------------------------------------------
		local util = require("translator.util")
		local translator = require("translator")

		-- 普通模式：翻译当前词（回显）
		vim.keymap.set("n", "<localLeader>te", function()
			translator.start("echo", { bang = false, range = 0, line1 = 1, line2 = 1, args = vim.fn.expand("<cword>") })
		end, { silent = true, desc = "翻译并回显（当前词）" })

		-- 普通模式：翻译当前句（回显）—— key 改为 tE，避免与"读原文"冲突
		vim.keymap.set("n", "<localLeader>tE", function()
			vim.cmd("normal! vis")
			local text = util.get_visual_selection()
			translator.start("echo", { bang = false, range = 2, line1 = 1, line2 = 1, args = text })
		end, { silent = true, desc = "翻译并回显（当前句）" })

		-- 窗口显示（当前词）
		vim.keymap.set("n", "<localleader>tw", function()
			translator.start(
				"window",
				{ bang = false, range = 0, line1 = 1, line2 = 1, args = vim.fn.expand("<cword>") }
			)
		end, { silent = true, desc = "翻译并窗口显示（当前词）" })

		vim.keymap.set("n", "<localleader>ti", "<Cmd>TranslateI<CR>", { desc = "交互翻译" })

		-- API 文档翻译（面向代码符号，需配置 translator_llm）
		vim.keymap.set("n", "<localLeader>td", "<Cmd>TranslateApi<CR>", { desc = "API 文档翻译" })
		vim.keymap.set("v", "<localLeader>td", ":TranslateApi<CR>", { desc = "API 文档翻译" })

		-- 替换当前词
		vim.keymap.set("n", "<localLeader>tr", function()
			vim.cmd("normal! viw")
			local text = util.get_visual_selection()
			translator.start("replace", { bang = false, range = 2, line1 = 1, line2 = 1, args = text })
		end, { silent = true, desc = "翻译并替换（当前词）" })

		-- 翻译剪贴板
		vim.keymap.set("n", "<localLeader>tx", function()
			translator.start("echo", { bang = false, range = 0, line1 = 1, line2 = 1, args = vim.fn.getreg("*") })
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
			translator.start("echo", { bang = false, range = 2, line1 = 1, line2 = 1, args = text })
		end, { silent = true, desc = "翻译并回显（选区）" })

		vim.keymap.set("v", "<localleader>tw", function()
			local text = util.get_visual_selection()
			translator.start("window", { bang = false, range = 2, line1 = 1, line2 = 1, args = text })
		end, { silent = true, desc = "翻译并窗口显示（选区）" })

		vim.keymap.set("v", "<localLeader>tr", function()
			local text = util.get_visual_selection()
			translator.start("replace", { bang = false, range = 2, line1 = 1, line2 = 1, args = text })
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
		vim.keymap.set(
			"n",
			"<localLeader>tc",
			"<Cmd>TranslateCacheClear<CR>",
			{ silent = true, desc = "清空翻译缓存" }
		)

		-- 强制刷新（绕过缓存）：等价于 :Translate --no-cache
		vim.keymap.set("n", "<localLeader>tC", function()
			translator.start(
				"window",
				{ bang = false, range = 0, line1 = 1, line2 = 1, args = "--no-cache " .. vim.fn.expand("<cword>") }
			)
		end, { silent = true, desc = "翻译并窗口显示（强制刷新）" })
	end,
}
