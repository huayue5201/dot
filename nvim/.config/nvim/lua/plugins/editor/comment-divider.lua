-- https://github.com/fangjunzhou/comment-divider.nvim
-- 在光标所在行「下面」插入注释分隔线 / 三行注释框。宽度上限含缩进，默认 80（与 colorcolumn 对齐）。
-- 纯 Lua 无依赖，:CommentDivider {line,box,status,filetype} 由 plugin/comment-divider.lua 注册。

return {
	"fangjunzhou/comment-divider.nvim",
	-- 仓库名带 .nvim，自动推断会 require("comment-divider.nvim")，必须显式指定
	main = "comment-divider",

	keys = {
		{
			"gc-",
			function()
				require("comment-divider").commentLine()
			end,
			desc = "注释分隔线（插入到下方）",
		},
		{
			"gc=",
			function()
				require("comment-divider").commentBox()
			end,
			desc = "注释框（插入到下方）",
		},
	},

	opts = {
		maxLineWidth = 80,
		-- 默认只预置 cpp / python / lua；下面补上其余常见的注释风格。
		-- 默认的 defaultStyle 是 C 系 `/* ... */`，脚本/标记语言必须显式覆盖。
		filetypeStyles = {
			html = { lineStart = "<!--", barrierCharacter = "-", lineEnd = "-->" },
			markdown = { lineStart = "<!--", barrierCharacter = "-", lineEnd = "-->" },
			-- rust / go 用行注释 `//`，不是 C 系 `/* */`
			rust = { lineStart = "//", barrierCharacter = "-", lineEnd = "//" },
			go = { lineStart = "//", barrierCharacter = "-", lineEnd = "//" },
			sql = { lineStart = "--", barrierCharacter = "-", lineEnd = "--" },
			sh = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			bash = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			zsh = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			fish = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			yaml = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			toml = { lineStart = "#", barrierCharacter = "-", lineEnd = "#" },
			vim = { lineStart = '"', barrierCharacter = "-", lineEnd = '"' },
			tex = { lineStart = "%", barrierCharacter = "-", lineEnd = "%" },
		},
	},
}
