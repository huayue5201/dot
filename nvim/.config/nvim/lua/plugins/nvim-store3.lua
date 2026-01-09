return {
	dir = "~/nvim-store3",
	name = "nvim-store3",
	main = "nvim-store3", -- 核心修复：明确指定主模块，阻止 lazy.nvim 自动分析内部配置
	-- event = "VimEnter",

	-- 可选：添加你自己的配置函数（如果需要的话）
	-- config = function()
	--     local store = require("nvim-store3")
	--     -- 你可以在这里调用 store.global() 或 store.project() 进行初始化
	-- end
}
