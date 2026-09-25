-- https://neovim.io/
-- https://devhints.io/vim
-- https://github.com/neovim/neovim/releases/tag/nightly

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 立即加载基础配置
require("core.settings") -- 基础 Neovim 选项
require("core.lazy") -- Lazy.nvim 插件管理（插件的懒加载由 Lazy.nvim 负责）
require("lsp-config").setup() --lsp
require("core.statusline") -- 状态栏（加载即自动构建并设置，无需手动调用 active）

-- 延迟执行不必要的设置，提升启动速度
vim.defer_fn(function()
	require("core.autocmds") -- 加载自动命令
	require("core.keymaps") -- 加载按键映射

	-- 延迟修改 runtimepath，避免影响启动速度
	vim.schedule(function()
		require("user.dotenv").load() -- token加载模块
		-- require("user.hl_undo_changes") -- undo高亮
	end)
end, 300)
