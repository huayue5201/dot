-- https://github.com/psliwka/vim-dirtytalk
--
-- 只是词表（programming 语言字典），本身不做任何开关；配合 lua/feat/spell.lua 使用。
-- 上游的 `:DirtytalkUpdate`（build 步骤）在 Neovim 里必失败：它调 Vim 专有的
-- spellfile#WritableSpellDir()，nvim 没这函数（E117）。所以 build 走自己的实现，
-- 产物落在 stdpath("config")/spell/programming.utf-8.spl。

return {
	"psliwka/vim-dirtytalk",
	build = function(plugin)
		require("feat.spell").build(plugin.dir)
	end,
}
