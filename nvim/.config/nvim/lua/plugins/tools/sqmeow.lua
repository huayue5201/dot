-- https://github.com/2giosangmitom/sqmeow.nvim
-- 数据库工作台（多库：SQL / NoSQL / 分析库）。引擎是独立 Rust 进程 sqmeow-core：
--   build 时自动下载预编译二进制到 stdpath('data')/sqmeow/bin/
--   没有对应预编译包时回退 `cargo build`（需本机有 Rust）。
-- 键位统一收纳在 <leader>g 分组（数据库操作较常用，占用空格前缀；原 grug-far 让位到 <localleader>g）。
return {
	-- 本地目录模式：vim.pack 把绝对路径当作安装源，clone 一份副本到
	-- stdpath("data")/site/pack/core/opt 下，nvim 实际加载的是副本。改完源码后
	-- `:PackLocalSync`（<leader>zp）同步副本，重启生效。
	-- dir = "~/neovim-plugins/sqmeow.nvim",
	-- 本地仓库 ~/neovim-plugins/sqmeow.nvim 只用于开发/提 PR；要临时试本地改动时，
	-- 再加回 dir = "~/neovim-plugins/sqmeow.nvim" 并 :PackLocalSync，试完删掉。
	"2giosangmitom/sqmeow.nvim",
	dependencies = { "MunifTanjim/nui.nvim" },
	keys = {
		-- 只写带实际 rhs 的按键：加载器把 keys 注册成普通映射，纯 lhs 条目会
		-- 退化成 lhs→lhs 的空映射（还会覆盖 config 里定义的真实映射）。
		-- 分组标签统一写在 lua/plugins/ui/which-key.lua 的 wk.add 里。
		{ "<leader>go", "<cmd>Sqmeow<cr>", desc = "Open workspace" },
		{ "<leader>gt", "<cmd>Sqmeow toggle<cr>", desc = "Show/hide window" },
		{ "<leader>gc", "<cmd>Sqmeow add<cr>", desc = "Add connection" },
		{ "<leader>gu", "<cmd>Sqmeow use<cr>", desc = "Switch active connection" },
		{ "<leader>gb", "<cmd>Sqmeow bind<cr>", desc = "Bind buffer to connection" },
		{ "<leader>gS", "<cmd>Sqmeow scratch<cr>", desc = "New scratchpad" },
		{ "<leader>gx", "<cmd>Sqmeow execute<cr>", desc = "Execute whole-buffer SQL" },
		{ "<leader>gs", "<cmd>Sqmeow statement<cr>", desc = "Execute statement under cursor" },
		{ "<leader>gX", "<cmd>Sqmeow cancel<cr>", desc = "Cancel running query" },
		{ "<leader>gn", "<cmd>Sqmeow next<cr>", desc = "Next result page" },
		{ "<leader>gp", "<cmd>Sqmeow prev<cr>", desc = "Previous result page" },
		{ "<leader>gv", "<cmd>Sqmeow float<cr>", desc = "Toggle result window float/split" },
		{ "<leader>gr", "<cmd>Sqmeow review<cr>", desc = "Review staged changes" },
		{ "<leader>ge", "<cmd>Sqmeow export<cr>", desc = "Export results" },
		{ "<leader>gl", "<cmd>Sqmeow log<cr>", desc = "Result history" },
		{ "<leader>gd", "<cmd>Sqmeow disconnect<cr>", desc = "Disconnect current connection" },
		{ "<leader>gm", "<cmd>Sqmeow messages<cr>", desc = "View engine logs" },
		{ "<leader>gh", "<cmd>Sqmeow health<cr>", desc = "Self-check" },
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
