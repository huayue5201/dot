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
require("config.statusline").active()
-- 延迟执行不必要的设置，提升启动速度
vim.defer_fn(function()
	require("config.autocmds") -- 加载自动命令
	require("config.keymaps") -- 加载按键映射

	require("utils.per_project_lsp").init()
	if not vim.g.lsp_enabled then
		vim.lsp.enable(require("config.lsp").get_lsp_config("name"), false)
		require("lint").linters_by_ft = {
			-- https://github.com/danmar/cppcheck/
			c = { "cppcheck" },
		}
		local icons = require("utils.utils").icons.diagnostic
		local ns = require("lint").get_namespace("cppcheck")
		vim.diagnostic.config({
			virtual_text = { current_line = false },
			virtual_lines = { current_line = true },
			signs = {
				text = {
					[vim.diagnostic.severity.ERROR] = icons.ERROR,
					[vim.diagnostic.severity.WARN] = icons.WARN,
					[vim.diagnostic.severity.HINT] = icons.HINT,
					[vim.diagnostic.severity.INFO] = icons.INFO,
				},
			},
		}, ns)

		vim.api.nvim_create_autocmd({ "BufWritePost", "BufEnter", "InsertLeave" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	else
		vim.lsp.enable(require("config.lsp").get_lsp_config("name"), true)
	end

	-- 延迟修改 runtimepath，避免影响启动速度
	vim.schedule(function()
		-- 延迟 LSP 配置
		vim.lsp.config("*", {
			root_markers = { ".git" },
			settings = {
				workspace = {
					didChangeWatchedFiles = {
						enabled = true,
					},
				},
			},
			capabilities = {
				textDocument = {
					semanticTokens = { multilineTokenSupport = true },
				},
			},
			on_attach = function(client)
				-- 确保 diagnostics 功能已启用
				client.server_capabilities.publishDiagnostics = true
			end,
		})
		require("utils.dotenv").load() -- token加载模块
		require("utils.info-dashboard") -- 信息展示版
	end)
end, 150) -- 延迟 100ms 执行
