-- https://github.com/antoinemadec/FixCursorHold.nvim

return {
	"antoinemadec/FixCursorHold.nvim",
	event = "BufReadPost",
	cnofng = function()
		--  in millisecond, used for both CursorHold and CursorHoldI,
		--  use updatetime instead if not defined
		vim.g.cursorhold_updatetime = 100
	end,
}
