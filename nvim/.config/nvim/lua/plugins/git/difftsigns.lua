-- https://github.com/janbuchar/difftsigns.nvim
--
-- 把 gitsigns 的改动栏按「结构差异」重新上色：pretter 重排 / 整体缩进这类纯格式噪音
-- 会被 dim 成 DifftSignsNoise，真正改动的行保持原色。它不新建视图窗口，只是在
-- gitsigns 已有的那一列里换颜色，`]c` 等 gitsigns 键位照常可用。
--
-- 依赖：gitsigns.nvim（必需，不是可选）+ difftastic 在 PATH 上。
-- 本机 Homebrew 装的是 difftastic 0.72.0，上游只验证过 0.70/0.71（difft 的 JSON
-- schema 明确声明不稳定），实测 0.72 的 overlay/preview 解析正常，所以把 0.72.0
-- 加进白名单，免得每次启动弹 WARN。上游验证新版本后可以删掉这一行。
local difft_versions = { "0.70.0", "0.71.0", "0.72.0" }

return {
	"janbuchar/difftsigns.nvim",
	dependencies = { "lewis6991/gitsigns.nvim" },
	keys = {
		{ "<leader>hD", "<cmd>DifftSigns preview<cr>", desc = "[D]ifftastic: 结构化 diff 预览" },
		{ "<leader>hT", "<cmd>DifftSigns toggle<cr>", desc = "[T]oggle 结构化改动栏" },
	},
	opts = {
		difft_versions = difft_versions,
		-- 400ms 是上游默认值，一次 difft 的耗时量级；再短会在大文件上排队
		debounce_ms = 400,
		-- 与 difft 自己的 --byte-limit 对齐（1MB）
		max_filesize = 1024 * 1024,
		-- graph_limit = nil 表示用 difft 默认（3,000,000）；重改动的文件里 diff
		-- 会先烧 8 秒然后放弃并退回行级 diff，插件此时只显示普通 gitsigns。
		-- 真遇到这种情况先看 :DifftSigns status，再把这里调大。
		graph_limit = nil,
	},
}
