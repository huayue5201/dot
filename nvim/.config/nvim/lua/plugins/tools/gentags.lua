-- https://github.com/linrongbin16/gentags.nvim
-- universal-ctags 后端（brew install universal-ctags）。
-- 注意：macOS 自带 /usr/bin/ctags 是老 BSD ctags，不支持 -R，gentags 会静默失败；
-- ~/.local/bin/ctags 已软链到 brew 版（PATH 里更靠前），确保 type -a ctags 第一个是它。
--
-- ctags 只作为 LSP 的补充：整仓符号检索 + SQL 这种 LSP 覆盖弱的文件类型
-- （universal-ctags 的 SQL parser 能索引 CREATE TABLE 的表名/列名，sqls 只知道库 schema）。
return {
	"linrongbin16/gentags.nvim",
	config = function()
		require("gentags").setup({
			ctags = {
				"--tag-relative=never",
				-- 大目录必须排除，否则 target/ 会产出几十万条垃圾 tag
				"--exclude=target",
				"--exclude=.git",
				"--exclude=node_modules",
				"--exclude=.todo2",
				"--exclude=data",
				"--exclude=tags",
			},
			-- 缓存里存的是每个 workspace 一份 tags；历史上在 / 和 /opt/homebrew 里生成过 1.7GB，
			-- 加个上限让 LRU 自动清掉大文件
			gc = { policy = "LRU", trigger = { name = "size", value = "500MB" } },
		})
	end,
}
