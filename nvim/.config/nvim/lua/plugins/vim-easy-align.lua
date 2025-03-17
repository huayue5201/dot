-- https://github.com/junegunn/vim-easy-align

return {
	"junegunn/vim-easy-align",
	keys = { "gs" },
	config = function()
		vim.keymap.set("x", "gs", "<Plug>(EasyAlign)", {   silent = true })
		-- 对于普通模式，启动 EasyAlign
		vim.keymap.set("n", "gs", "<Plug>(EasyAlign)", {   silent = true })
	end,
}
