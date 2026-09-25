-- 统一的快捷键配置表（数据）
-- 格式：
--   [按键] = {
--     [filetype或buftype] = {
--       cmd = "命令字符串" 或 function,
--       desc = "描述信息（可选）"
--     }
--   }
-- 特殊命令：next_error, prev_error, next_error_repeatable, prev_error_repeatable, smart_close
return {
	-- 关闭窗口（q 键）
	["q"] = {
		help = { cmd = "quit", desc = "关闭帮助窗口" },
		man = { cmd = "quit", desc = "关闭 man 窗口" },
		msgmore = { cmd = "quit", desc = "关闭消息窗口" },
		FunctionReferences = { cmd = "quit", desc = "关闭引用窗口" },
		checkhealth = { cmd = "close", desc = "关闭健康检查" },
		better_term = { cmd = "close", desc = "关闭终端" },
		["grug-far"] = { cmd = "bdelete", desc = "关闭搜索替换" },
		git = { cmd = "bdelete", desc = "关闭 git 窗口" },
		["dap-repl"] = { cmd = "close", desc = "关闭 DAP REPL" },
		["dap-float"] = { cmd = "close", desc = "关闭 DAP 浮动窗" },
		["dap-view-term"] = { cmd = "close", desc = "关闭 DAP 终端" },
		["dap-view"] = { cmd = "DapViewClose", desc = "关闭 DAP 视图" },
		["gitsigns-blame"] = { cmd = "bdelete!", desc = "关闭 blame" },
		terminal = { cmd = "bdelete", desc = "关闭终端" },
		["nvim-undotree"] = { cmd = "close", desc = "关闭 undotree" },
		["vscode-diff-explorer"] = { cmd = "tabclose", desc = "关闭 diff" },
		OverseerOutput = { cmd = "close", desc = "关闭任务输出" },
		["neotest-summary"] = { cmd = "close", desc = "关闭测试摘要" },
		["neotest-output"] = { cmd = "close", desc = "关闭测试输出" },
		["neotest-output-panel"] = { cmd = "close", desc = "关闭测试输出面板" },
	},

	-- 错误跳转：下一个（]d 键），使用 next_error_repeatable 支持 . 重复
	["]d"] = {
		["better_term"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "next_error_repeatable", desc = "下一个错误（支持 . 重复）" },
	},

	-- 错误跳转：上一个（[d 键），使用 prev_error_repeatable 支持 . 重复
	["[d"] = {
		["better_term"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
		["neotest-output"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
		["neotest-output-panel"] = { cmd = "prev_error_repeatable", desc = "上一个错误（支持 . 重复）" },
	},
}
