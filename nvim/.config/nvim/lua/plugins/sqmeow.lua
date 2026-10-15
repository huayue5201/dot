-- https://github.com/2giosangmitom/sqmeow.nvim
-- 数据库工作台（多库：SQL / NoSQL / 分析库）。引擎是独立 Rust 进程 sqmeow-core：
--   build 时自动下载预编译二进制到 stdpath('data')/sqmeow/bin/
--   没有对应预编译包时回退 `cargo build`（需本机有 Rust）。
-- 键位统一收纳在 <localleader>g 分组（原 dadbod-grip 的命名空间），默认 localleader = \。
return {
	"2giosangmitom/sqmeow.nvim",
	sem_version = "*",
	dependencies = { "MunifTanjim/nui.nvim" },
	cmd = "Sqmeow",
	keys = {
		-- 注意：不要再写 { "<localleader>g", desc = ... } 当分组标签。lazy.nvim 会给它
		-- 建一个 lazy-load 映射，第一次按 \g 只触发加载、看不到效果，第二次才弹出分组。
		-- 分组标签统一在 lua/plugins/which-key.lua 的 wk.add 里声明。
		{ "<localleader>go", "<cmd>Sqmeow<cr>", desc = "打开工作区" },
		{ "<localleader>gt", "<cmd>Sqmeow toggle<cr>", desc = "显示/隐藏窗口" },
		{ "<localleader>gc", "<cmd>Sqmeow add<cr>", desc = "添加连接" },
		{ "<localleader>gu", "<cmd>Sqmeow use<cr>", desc = "切换活动连接" },
		{ "<localleader>gb", "<cmd>Sqmeow bind<cr>", desc = "绑定 buffer 到连接" },
		{ "<localleader>gS", "<cmd>Sqmeow scratch<cr>", desc = "新建 scratchpad" },
		{ "<localleader>gx", "<cmd>Sqmeow execute<cr>", desc = "执行整 buffer SQL" },
		{ "<localleader>gs", "<cmd>Sqmeow statement<cr>", desc = "执行光标下语句" },
		{ "<localleader>gr", "<cmd>Sqmeow review<cr>", desc = "审查暂存改动" },
		{ "<localleader>ge", "<cmd>Sqmeow export<cr>", desc = "导出结果" },
		{ "<localleader>gl", "<cmd>Sqmeow log<cr>", desc = "结果历史" },
		{ "<localleader>gh", "<cmd>Sqmeow health<cr>", desc = "自检" },
	},
	build = function()
		require("sqmeow").install()
	end,
	opts = {},
}
