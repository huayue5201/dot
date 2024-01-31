-- https://github.com/andymass/vim-matchup

return {
	"andymass/vim-matchup",
	event = { "BufReadPre" },
	config = function()
		vim.g.matchup_matchparen_offscreen = { method = "popup" }
		vim.cmd([[
      let g:matchup_surround_enabled = 0
      let g:matchup_transmute_enabled = 1
      " 延迟高亮显示
      let g:matchup_matchparen_deferred = 1
      ]])
	end,
}
