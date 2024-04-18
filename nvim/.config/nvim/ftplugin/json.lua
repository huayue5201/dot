-- efm-langserver 配置
local efm_config = {
	init_options = {documentFormatting = true},
	filetypes = {
		json = "jsonlint",
	},
	settings = {
		rootMarkers = {".git/"},
		languages = {
			jsonlint = {
				lintCommand = "jsonlint",
				lintFormats = {"%f:%l:%c: %m"},
			},
		},
	},
}

-- 启动 efm-langserver
vim.lsp.start(vim.tbl_extend("force", {
	cmd = {"efm-langserver", "-logfile", "/tmp/efm.log"},
}, efm_config))

-- 调用自定义的 LSP 配置模块
require("user.lspconfig").lspSetup()
