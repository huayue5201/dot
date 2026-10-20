-- https://github.com/2giosangmitom/sqmeow.nvim
-- 数据库工作台（多库：SQL / NoSQL / 分析库）。引擎是独立 Rust 进程 sqmeow-core：
--   build 时自动下载预编译二进制到 stdpath('data')/sqmeow/bin/
--   没有对应预编译包时回退 `cargo build`（需本机有 Rust）。
-- 键位统一收纳在 <leader>g 分组（数据库操作较常用，占用空格前缀；原 grug-far 让位到 <localleader>g）。
return {
	-- 改成用本地仓库（zpack 的本地目录模式）：改 ~/neovim-plugins/sqmeow.nvim 里的代码后
	-- `:PackLocalSync`（<leader>zp）同步到 pack/core/opt 下的副本，重启生效。
	-- 要回到上游源：注释掉 dir 那行再 :PackLocalSync + :PackUpdate。
	dir = "~/neovim-plugins/sqmeow.nvim",
	-- 上游已合并 sticky header（PR #94），日常直接用上游源。
	-- 本地仓库 ~/neovim-plugins/sqmeow.nvim 只用于开发/提 PR；要临时试本地改动时，
	-- 再加回 dir = "~/neovim-plugins/sqmeow.nvim" 并 :PackLocalSync，试完删掉。
	dependencies = { "MunifTanjim/nui.nvim" },
	cmd = "Sqmeow",
	keys = {
		-- 注意：不要再写 { "<leader>g", desc = ... } 当分组标签。zpack 会给它
		-- 建一个 lazy-load 映射，第一次按 <leader>g 只触发加载、看不到效果，第二次才弹出分组。
		-- 分组标签统一在 lua/plugins/which-key.lua 的 wk.add 里声明。
		{ "<leader>go", "<cmd>Sqmeow<cr>", desc = "打开工作区" },
		{ "<leader>gt", "<cmd>Sqmeow toggle<cr>", desc = "显示/隐藏窗口" },
		{ "<leader>gc", "<cmd>Sqmeow add<cr>", desc = "添加连接" },
		{ "<leader>gu", "<cmd>Sqmeow use<cr>", desc = "切换活动连接" },
		{ "<leader>gb", "<cmd>Sqmeow bind<cr>", desc = "绑定 buffer 到连接" },
		{ "<leader>gS", "<cmd>Sqmeow scratch<cr>", desc = "新建 scratchpad" },
		{ "<leader>gx", "<cmd>Sqmeow execute<cr>", desc = "执行整 buffer SQL" },
		{ "<leader>gs", "<cmd>Sqmeow statement<cr>", desc = "执行光标下语句" },
		{ "<leader>gX", "<cmd>Sqmeow cancel<cr>", desc = "取消正在执行的查询" },
		{ "<leader>gn", "<cmd>Sqmeow next<cr>", desc = "结果下一页" },
		{ "<leader>gp", "<cmd>Sqmeow prev<cr>", desc = "结果上一页" },
		{ "<leader>gv", "<cmd>Sqmeow float<cr>", desc = "结果窗口浮窗/分屏切换" },
		{ "<leader>gr", "<cmd>Sqmeow review<cr>", desc = "审查暂存改动" },
		{ "<leader>ge", "<cmd>Sqmeow export<cr>", desc = "导出结果" },
		{ "<leader>gl", "<cmd>Sqmeow log<cr>", desc = "结果历史" },
		{ "<leader>gd", "<cmd>Sqmeow disconnect<cr>", desc = "断开当前连接" },
		{ "<leader>gm", "<cmd>Sqmeow messages<cr>", desc = "查看引擎日志" },
		{ "<leader>gh", "<cmd>Sqmeow health<cr>", desc = "自检" },
	},
	build = function()
		require("sqmeow").install()
	end,
	config = function()
		require("sqmeow").setup({
			ui = {
				drawer = { position = "right", width = 42 },
				result = {
					height = 16,
					page_size = 100,
					max_column_width = 48,
					-- 列名行一滚出屏幕就用 1 行浮窗钉住它（分隔线不管，会被盖住；代价是盖住 1 行数据）。
					sticky_header = true,
				},
				persist_session = false,
			},
			query = {
				max_rows = 100000,
				timeout_ms = 0,
				persist_history = true,
				confirm_destructive = true,
			},
			redact_urls = true,
		})
	end,
}
