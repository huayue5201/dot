-- https://github.com/mattn/efm-langserver

require("lspconfig").efm.setup({
	init_options = { documentFormatting = true },
	settings = {
		rootMarkers = { ".git/" },
		languages = {
			lua = {
				--  WARN: 需要安装stylua程序
				-- https://github.com/JohnnyMorganz/StyLua
				{ formatCommand = "stylua -", formatStdin = true },
			},
		},
	},
})
