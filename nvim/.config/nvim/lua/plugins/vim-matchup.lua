-- https://github.com/andymass/vim-matchup?tab=readme-ov-file

return {
	"andymass/vim-matchup",
	event = "BufReadPre",
	config = function()
		-- 启用预览功能
		vim.g.matchup_matchparen_offscreen = { method = "popup" }
		-- 启用 ds% 和 cs% map
		vim.g.matchup_surround_enabled = 1
		vim.g.matchup_transmute_enabled = 1
		-- 即使没有匹配，突出显示已知单词
		vim.g.matchup_matchparen_singleton = 1
		-- 延迟高亮显示
		vim.g.matchup_matchparen_deferred = 1
		vim.g.matchup_motion_override_Npercent = 100
		-- 高亮设置
	end,
}
