-- https://neovim.io/
-- https://devhints.io/vim
-- https://github.com/neovim/neovim/releases/

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- vim.filetype.add({
-- 	extension = {
-- 		cfg = "dosini",
-- 	},
-- })

vim.cmd([[
    au VimEnter,VimResume * set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
    \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
    \,sm:block-blinkwait175-blinkoff150-blinkon175
    au VimLeave,VimSuspend * set guicursor=a:block-blinkon0
]])

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- vim.lsp.enable({ "lua_ls", "pyright" })
-- 立即加载基础配置
require("env") -- 环境变量配置
require("lsp").setup() --lsp
require("core.settings") -- 基础 Neovim 选项
require("core.lazy") -- Lazy.nvim 插件管理（插件的懒加载由 Lazy.nvim 负责）
require("core.statusline").active() -- 状态栏

-- 延迟执行不必要的设置，提升启动速度
vim.defer_fn(function()
	require("core.autocmds") -- 加载自动命令
	require("core.keymaps") -- 加载按键映射

	-- 延迟修改 runtimepath，避免影响启动速度
	vim.schedule(function()
		require("bigfile").setup({
			debounce = 300, -- 检测延迟（毫秒）
		})
		require("user.dotenv").load() -- token加载模块
	end)
end, 300) -- 延迟 100ms 执行
