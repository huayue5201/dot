-- https://github.com/SunnyTamang/select-undo.nvim

return {
	"SunnyTamang/select-undo.nvim",
	-- 你可以选择什么时候加载，比如 BufReadPost
	config = function()
		require("select-undo").setup({
			persistent_undo = true, -- 是否启用持久化 undo 历史
			mapping = true, -- 是否启用默认按键映射
			line_mapping = "zu", -- 整行 undo 映射
			partial_mapping = "zpu", -- 部分（选中）undo 映射（你也可以改成别的键）
		})
	end,
}
