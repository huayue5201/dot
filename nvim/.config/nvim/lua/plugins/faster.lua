-- https://github.com/pteroctopus/faster.nvim

return {
	"pteroctopus/faster.nvim",
	event = "VeryLazy",
	config = function()
		require("faster").setup({
			behaviours = {
				bigfile = {
					on = true, -- 启用大文件处理
					features_disabled = { -- 遇到大文件时禁用以下功能
						"illuminate",
						"matchparen",
						"lsp",
						"treesitter",
						"vimopts",
						"syntax",
						"filetype",
					},
					filesize = 2, -- 文件大小阈值（单位：MB）
					pattern = "*", -- 应用于所有文件
					extra_patterns = { -- 为特定文件类型设置不同阈值
						-- { filesize = 1.1, pattern = "*.md" }, -- 示例：Markdown文件阈值设为1.1MB
						-- { filesize = 0.5, pattern = "*.js" },
					},
				},
				fastmacro = {
					on = true, -- 启用宏执行优化
					features_disabled = { "lualine", "mini_clue" }, -- 执行宏时禁用这些插件
				},
			},
			features = { -- 所有可管理功能默认开启
				filetype = { on = true, defer = true },
				illuminate = { on = true, defer = false },
				indent_blankline = { on = true, defer = false },
				lsp = { on = true, defer = false },
				lualine = { on = true, defer = false },
				matchparen = { on = true, defer = false },
				syntax = { on = true, defer = true },
				treesitter = { on = true, defer = false },
				vimopts = { on = true, defer = false },
				mini_clue = { on = true, defer = false },
			},
		})
	end,
}
