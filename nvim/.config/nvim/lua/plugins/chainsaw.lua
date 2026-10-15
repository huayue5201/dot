-- https://github.com/chrisgrieser/nvim-chainsaw
--
-- 智能插入各类打印/日志语句（替代 debugprint.nvim）。
-- 变量/对象/类型/断言/emoji/计时/堆栈/debugger/清屏，一键删除，全部支持 . 重复。
-- 依赖各语言的 Treesitter parser 做「变量识别」和「插入位置」推断。
-- 每条语句带唯一标记（默认 🪚），用于行高亮/sign/删除。
--
-- 键位沿用旧的 `g?` 家族，尽量贴合 debugprint 时的肌肉记忆。

return {
	"chrisgrieser/nvim-chainsaw",
	event = "VeryLazy",
	opts = {}, -- 必填，即使为空

	keys = {
		-- 变量 / 对象 / 类型 / 断言（n 与 x 模式都支持）
		{
			"g?v",
			function()
				require("chainsaw").variableLog()
			end,
			mode = { "n", "x" },
			desc = "打印：变量 (variableLog)",
		},
		{
			"g?o",
			function()
				require("chainsaw").objectLog()
			end,
			mode = { "n", "x" },
			desc = "打印：对象 (objectLog)",
		},
		{
			"g?t",
			function()
				require("chainsaw").typeLog()
			end,
			mode = { "n", "x" },
			desc = "打印：类型 (typeLog)",
		},
		{
			"g?a",
			function()
				require("chainsaw").assertLog()
			end,
			mode = { "n", "x" },
			desc = "打印：断言 (assertLog)",
		},

		-- 控制流 / 消息 / 声音
		{
			"g?e",
			function()
				require("chainsaw").emojiLog()
			end,
			desc = "打印：emoji 控制流 (emojiLog)",
		},
		{
			"g?m",
			function()
				require("chainsaw").messageLog()
			end,
			desc = "打印：消息 (messageLog)",
		},
		{
			"g?S",
			function()
				require("chainsaw").sound()
			end,
			desc = "打印：声音 (sound)",
		},

		-- 计时 / debugger / 堆栈 / 清屏
		{
			"g?T",
			function()
				require("chainsaw").timeLog()
			end,
			desc = "打印：计时 (timeLog)",
		},
		{
			"g?d",
			function()
				require("chainsaw").debugLog()
			end,
			desc = "打印：debugger 断点 (debugLog)",
		},
		{
			"g?s",
			function()
				require("chainsaw").stacktraceLog()
			end,
			desc = "打印：堆栈 (stacktraceLog)",
		},
		{
			"g?c",
			function()
				require("chainsaw").clearLog()
			end,
			desc = "打印：清屏 (clearLog)",
		},

		-- 删除本插件插入的语句（可视模式只删选中范围内的）
		{
			"g?x",
			function()
				require("chainsaw").removeLogs()
			end,
			mode = { "n", "x" },
			desc = "打印：删除所有 chainsaw 语句 (removeLogs)",
		},
	},
}
