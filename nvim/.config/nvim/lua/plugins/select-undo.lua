-- https://github.com/SunnyTamang/select-undo.nvim

return {
	"SunnyTamang/select-undo.nvim",
	config = function()
		require("select-undo").setup({
			line_mapping = "zu", -- Step undo mapping (frees gu for lowercasing)
			sweep_mapping = "zU", -- Sweep undo mapping (frees gU for uppercasing)
			partial_mapping = "zcu", -- Partial undo mapping
		})
	end,
}
