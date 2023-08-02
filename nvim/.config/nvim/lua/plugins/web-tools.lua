-- https://github.com/ray-x/web-tools.nvim
-- WARN: 需依赖外部程序browser-sync (MACOS:npm install -g browser-sync)
-- https://github.com/BrowserSync/browser-sync

return {
	"ray-x/web-tools.nvim",
	ft = { "html", "css" },
	opts = {
		keymaps = {
			rename = nil, -- by default use same setup of lspconfig
			repeat_rename = ".", -- . to repeat
		},
		hurl = { -- hurl default
			show_headers = false, -- do not show http headers
			floating = false, -- use floating windows (need guihua.lua)
			formatters = { -- format the result by filetype
				json = { "jq" },
				html = { "prettier", "--parser", "html" },
			},
		},
	},
}
