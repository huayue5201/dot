-- https://devhints.io/vim
-- https://github.com/neovim/neovim/releases/
-- https://neovim.io/

-- 启用 Lua 加载器加速启动
vim.loader.enable()

-- 光标配置（启动后设置，减少影响 UI 加载）
vim.cmd([[
    au VimEnter,VimResume * set guicursor=n-v-c:block,i-ci-ve:ver25,r-cr:hor20,o:hor50
    \,a:blinkwait700-blinkoff400-blinkon250-Cursor/lCursor
    \,sm:block-blinkwait175-blinkoff150-blinkon175
    au VimLeave,VimSuspend * set guicursor=a:block-blinkon0
    ]])

-- 设置 Leader 键为空格
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 立即加载基础配置
require("config.settings") -- 基础 Neovim 选项
require("config.lazy") -- Lazy.nvim 插件管理（插件的懒加载由 Lazy.nvim 负责）

-- 延迟执行不必要的设置，提升启动速度
vim.defer_fn(function()
	require("config.autocmds") -- 延迟加载自动命令
	require("config.usercmds") -- 延迟加载用户命令
	require("config.keymaps") -- 延迟加载按键映射
	require("utils.dotenv").load() -- token加载模块

	-- 延迟 LSP 配置
	vim.lsp.config("*", {
		root_markers = { ".git" },
		capabilities = {
			textDocument = {
				semanticTokens = { multilineTokenSupport = true },
			},
		},
	})
	vim.lsp.enable({ "lua_ls", "clangd", "taplo", "rust-analyzer" })

	-- 延迟修改 runtimepath，避免影响启动速度
	vim.schedule(function()
		vim.opt.runtimepath:append("/opt/homebrew/opt/fzf")
	end)

	-- 颜色主题（如果需要的话）
	-- vim.cmd("colorscheme ansi")
end, 150) -- 延迟 100ms 执行
