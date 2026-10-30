-- https://github.com/Zeioth/markmap.nvim
-- 把当前 markdown 文件渲染成思维导图（markmap → HTML，用浏览器打开）。
-- 外部依赖：可执行文件 `markmap`（markmap-cli），本机已 `npm i -g markmap-cli` 装好，
-- 所以不需要插件 README 里那步 `yarn global add markmap-cli`（build 字段就省略了）。
-- 命令：:MarkmapOpen（打开）:MarkmapSave（只生成 html）:MarkmapWatch（改动即刷新）
--       :MarkmapWatchStop，:checkhealth markmap 可查依赖是否齐。
return {
	"Zeioth/markmap.nvim",
	sem_version = "*",
	opts = {
		-- 空字符串 = 跟当前文件同目录同名 .html；这里固定写到 /tmp，避免污染笔记仓库
		html_output = "/tmp/markmap.html",
		hide_toolbar = false,
	},
	config = function(_, opts)
		require("markmap").setup(opts)
	end,
	keys = {
		{ "<localleader>mm", "<cmd>MarkmapOpen<cr>", desc = "Markmap: 打开思维导图" },
		{ "<localleader>mw", "<cmd>MarkmapWatch<cr>", desc = "Markmap: 打开并实时刷新" },
		{ "<localleader>ms", "<cmd>MarkmapSave<cr>", desc = "Markmap: 只保存 html" },
		{ "<localleader>mS", "<cmd>MarkmapWatchStop<cr>", desc = "Markmap: 停止刷新" },
	},
}
