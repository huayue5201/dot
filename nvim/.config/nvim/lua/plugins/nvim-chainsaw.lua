-- https://github.com/chrisgrieser/nvim-chainsaw

return {
	"chrisgrieser/nvim-chainsaw",
	event = "VeryLazy",
	config = function()
		require("chainsaw").setup({
			-- 标记符应该是唯一的字符串，因为标记符会用于 sign 和 highlight。
			-- 此外，`.removeLogs()` 会删除任何包含该标记符的行。
			-- 因此推荐使用独特的 emoji 或字符串，如 "[Chainsaw]"。
			marker = "🪚",

			-- 带有标记符行的外观
			visuals = {
				icon = "󰹈", ---@type string|false 与 marker 相对，仅在 nvim 使用，因此 nerdfont 字符可以
				signHlgroup = "DiagnosticSignInfo", ---@type string|false
				signPriority = 50,
				lineHlgroup = false, ---@type string|false

				nvimSatelliteIntegration = {
					enabled = true,
					hlgroup = "DiagnosticSignInfo",
					icon = "▪",
					leftOfScrollbar = false,
					priority = 40, -- 与其他处理程序比较（诊断是 50）
				},
			},

			-- 自动安装 pre-commit 钩子，防止提交包含标记符的代码
			-- 如果已经存在其他 pre-commit 钩子，则不会安装。
			preCommitHook = {
				enabled = false,
				notifyOnInstall = true,
				hookPath = ".chainsaw", -- 相对于 git 根目录

				-- 将标记符插入为 `%s`。（阻止提交时，pre-commit 钩子需要 shebang 并在发现标记符时非零退出。）
				hookContent = [[#!/bin/sh
			if git grep --fixed-strings --line-number "%s" .; then
				echo
				echo "nvim-chainsaw 标记符被发现，提交终止。"
				exit 1
			fi
		]],

				-- 如果你通过 git 跟踪你的 nvim 配置，并使用自定义标记符，
				-- 因为配置中总会包含标记符，这可能会误触 pre-commit 钩子。
				notInNvimConfigDir = true,

				-- 不安装钩子的 git 根目录列表。支持 glob 和 `~`。
				-- 必须匹配完整目录。
				dontInstallInDirs = {
					-- "~/special-project"
					-- "~/repos/**",
				},
			},

			-- 针对特定日志类型的配置
			logTypes = {
				emojiLog = {
					emojis = { "🔵", "🟩", "⭐", "⭕", "💜", "🔲" },
				},
			},

			-----------------------------------------------------------------------------
			-- 参见 https://github.com/chrisgrieser/nvim-chainsaw/blob/main/lua/chainsaw/config/log-statements-data.lua
			logStatements = require("chainsaw.config.log-statements-data").logStatements,
			supersets = require("chainsaw.config.log-statements-data").supersets,
		})

		local chainsaw = require("chainsaw")

		local fzf = require("fzf-lua")
		local marker = require("chainsaw.config.config").config.marker

		vim.keymap.set("n", "g?f", function()
			fzf.grep({
				search = marker,
				rg_opts = "--trim",
				prompt = marker .. " logs> ",
				header = "Search for " .. marker .. " log statements",
			})
		end, { desc = "Chainsaw: search log statements" })

		-- Normal mode mappings with Chinese descriptions
		vim.keymap.set(
			"n",
			"g?v",
			chainsaw.variableLog,
			{ desc = "Chainsaw: 打印光标下变量及值", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?o",
			chainsaw.objectLog,
			{ desc = "Chainsaw: 打印光标下对象内容", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?t",
			chainsaw.typeLog,
			{ desc = "Chainsaw: 打印光标下变量类型", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?a",
			chainsaw.assertLog,
			{ desc = "Chainsaw: 变量断言日志", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?e",
			chainsaw.emojiLog,
			{ desc = "Chainsaw: 简易 Emoji 日志", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?s",
			chainsaw.sound,
			{ desc = "Chainsaw: 播放调试声音", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?m",
			chainsaw.messageLog,
			{ desc = "Chainsaw: 自定义消息日志", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?T",
			chainsaw.timeLog,
			{ desc = "Chainsaw: 测量代码执行时间", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?d",
			chainsaw.debugLog,
			{ desc = "Chainsaw: 插入调试断点", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?S",
			chainsaw.stacktraceLog,
			{ desc = "Chainsaw: 打印当前调用栈", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?c",
			chainsaw.clearLog,
			{ desc = "Chainsaw: 清空日志输出", noremap = true, silent = true }
		)
		vim.keymap.set(
			"n",
			"g?x",
			chainsaw.removeLogs,
			{ desc = "Chainsaw: 删除所有日志语句", noremap = true, silent = true }
		)
	end,
}
