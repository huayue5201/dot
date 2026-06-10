-- https://github.com/folke/lazydev.nvim

return {
	"folke/lazydev.nvim",
	ft = "lua", -- 仅在打开 Lua 文件时加载
	config = function()
		require("lazydev").setup({
			-- ============================================================
			-- 库路径配置
			-- ============================================================
			library = {
				-- 1. Neovim 运行时类型（会自动解析）
				-- 这些是 lazydev 自带的，不需要额外安装
				"nvim-runtime", -- Neovim 核心 API
				"vim-runtime", -- Vim 兼容 API

				-- 2. 你正在开发的插件（绝对路径）
				-- 修改为你的实际插件路径
				"~/neovim-plugins/neotest-rust",
				-- "~/neovim-plugins/your-other-plugin",

				-- 3. 自动加载 luv 类型（vim.uv / vim.loop）
				{ path = "${3rd}/luv/library", words = { "vim%.uv", "vim%.loop" } },

				-- 4. 你本地的 Neovim 配置目录
				vim.fn.stdpath("config"), -- ~/.config/nvim
			},

			-- ============================================================
			-- 启用条件
			-- ============================================================
			enabled = function(root_dir)
				-- 如果存在 .luarc.json，说明用户有自己配置 Lua LSP，则禁用
				if vim.uv.fs_stat(root_dir .. "/.luarc.json") then
					return false
				end
				return true
			end,
		})
	end,
}
