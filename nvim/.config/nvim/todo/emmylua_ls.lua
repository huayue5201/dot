-- https://github.com/EmmyLuaLs/emmylua-analyzer-rust?tab=readme-ov-file#-installation

return {
	cmd = { "emmylua_ls" },
	root_markers = {
		".git/",
		".luarc.json",
		".emmyrc.json",
		".luacheckrc",
	},
	filetypes = { "lua" },
	single_file_support = true,
	settings = {
		Lua = {
			runtime = {
				version = "LuaJIT",
			},
			workspace = {
				checkThirdParty = false, -- 避免不必要的检查
				library = {
					-- Neovim 运行时文件
					vim.env.VIMRUNTIME,
					-- 你的 Neovim 配置目录
					vim.fn.stdpath("config"),
					-- 可选：特定插件的路径
					-- vim.fn.expand("~/.local/share/nvim/site/pack/packer/start/一些插件名"),
				},
			},
			telemetry = {
				enable = false,
			},
		},
	},
}
