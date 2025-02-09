-- https://git.sr.ht/~alphakeks/.dotfiles/tree/717cc8fc8f5b5cc10a30ae4dab6fa0a699e94e06/item/nvim/colors/dawn.lua
--- Name:        dawn
--- Description: The best colorscheme there is.
--- Author:      AlphaKeks <alphakeks@dawn.sh>
--- License:     GPL 3.0

vim.opt.background = "dark"
vim.cmd.source("$VIMRUNTIME/colors/default.vim")
vim.g.colors_name = "dawn"

local colors = {
	poggers = "#7480c2",
	background = "#11111b",
	shade = "#1e1e2e",
	comment = "#3c5e7f",
	delimiter = "#6c7086",
	foreground_dark = "#313244",
	foreground = "#585b70",
	text = "#cdd6f4",
	lavender = "#b4befe",
	blue = "#89b4fa",
	green = "#a6e3a1",
	yellow = "#f9e2af",
	orange = "#fab387",
	red = "#f38ba8",
	purple = "#cba6f7",
}

-- unmodified catppuccin to match my terminal theme:
-- https://github.com/catppuccin/base16/blob/99aa911b29c9c7972f7e1d868b6242507efd508c/base16/mocha.yaml
local terminal_colors = {
	[0] = "1e1e2e", -- base
	[1] = "181825", -- mantle
	[2] = "313244", -- surface0
	[3] = "45475a", -- surface1
	[4] = "585b70", -- surface2
	[5] = "cdd6f4", -- text
	[6] = "f5e0dc", -- rosewater
	[7] = "b4befe", -- lavender
	[8] = "f38ba8", -- red
	[9] = "fab387", -- peach
	[10] = "f9e2af", -- yellow
	[11] = "a6e3a1", -- green
	[12] = "94e2d5", -- teal
	[13] = "89b4fa", -- blue
	[14] = "cba6f7", -- mauve
	[15] = "f2cdcd", -- flamingo
}

for idx, color in pairs(terminal_colors) do
	vim.g["terminal_color_" .. tostring(idx)] = color
end

local highlight_groups = {
	-- editor
	["ColorColumn"] = { bg = colors.shade },
	["Conceal"] = { link = "NONE" },
	["CurSearch"] = { bg = colors.poggers, fg = colors.background },
	["Cursor"] = { bg = colors.poggers, fg = colors.background },
	["lCursor"] = { link = "Cursor" },
	["CursorIM"] = { link = "Cursor" },
	["CursorColumn"] = { link = "ColorColumn" },
	["CursorLine"] = { link = "CursorColumn" },
	["Directory"] = { fg = colors.blue },
	["DiffAdd"] = { bg = colors.green, fg = colors.background },
	["DiffChange"] = { bg = colors.blue, fg = colors.background },
	["DiffDelete"] = { bg = colors.red, fg = colors.background },
	["DiffText"] = { link = "Normal" },
	["EndOfBuffer"] = { fg = colors.foreground_dark },
	["TermCursor"] = { bg = colors.text },
	["WinSeparator"] = { link = "NONE" },
	["Folded"] = { link = "Comment" },
	["FoldColumn"] = { link = "SignColumn" },
	["SignColumn"] = { link = "Normal" },
	["LineNr"] = { fg = colors.foreground_dark },
	["CursorLineNr"] = { fg = colors.lavender },
	["CursorLineFold"] = { link = "NONE" },
	["CursorLineSign"] = { link = "NONE" },
	["MatchParen"] = { bg = colors.foreground },
	["ModeMsg"] = { fg = colors.poggers, italic = true },
	["MsgSeparator"] = { bg = colors.foreground },
	["Normal"] = { bg = colors.background, fg = colors.text },
	["NormalFloat"] = { bg = "NONE" },
	["FloatBoarder"] = { bg = "NONE" },
	["FloatTitle"] = { bg = "NONE" },
	["FloatFooter"] = { bg = "NONE" },
	["Pmenu"] = { bg = colors.shade, fg = colors.foreground },
	["PmenuSel"] = { bg = colors.foreground_dark, fg = colors.colors_foreground },
	["PmenuThumb"] = { bg = colors.foreground_dark },
	["QuickFixLine"] = { fg = colors.yellow },
	["Search"] = { bg = colors.yellow, fg = colors.background },
	["StatusLine"] = { bg = colors.background, fg = colors.text },
	["StatusLineNC"] = { bg = colors.background, fg = colors.shade },
	["StatusLineDiagnosticError"] = { bg = colors.background, fg = colors.red },
	["StatusLineDiagnosticWarn"] = { bg = colors.background, fg = colors.yellow },
	["StatusLineDiagnosticInfo"] = { bg = colors.background, fg = colors.green },
	["StatusLineDiagnosticHint"] = { bg = colors.background, fg = colors.blue },
	["TabLine"] = { bg = colors.background, fg = colors.foreground },
	["TabLineSel"] = { link = "StatusLine" },
	["TabLineFill"] = { bg = colors.background, fg = colors.background },
	["Title"] = { fg = colors.poggers, bold = true },
	["Visual"] = { bg = colors.foreground_dark },
	["Whitespace"] = { fg = colors.shade },
	-- 设置默认的 winbar 高亮
	["WinBar"] = { fg = colors.yellow, bold = true }, -- 设置 winbar 默认颜色为橙色并加粗
	["WinBarSpecial"] = { fg = colors.blue, bold = true }, -- 设置特殊目录为绿色并加粗
	["WinBarSeparator"] = { fg = colors.poggers }, -- 设置分隔符颜色为灰色
	["WinBarNC"] = { link = "WinBar" },

	-- lsp诊断相关
	["DiagnosticError"] = { fg = colors.red },
	["DiagnosticWarn"] = { fg = colors.yellow },
	["DiagnosticInfo"] = { fg = colors.green },
	["DiagnosticHint"] = { fg = colors.blue },
	["DiagnosticOk"] = { link = "NONE" },
	["DiagnosticUnderlineError"] = { link = "NONE" },
	["DiagnosticUnderlineWarn"] = { link = "NONE" },
	["DiagnosticUnderlineInfo"] = { link = "NONE" },
	["DiagnosticUnderlineHint"] = { link = "NONE" },
	["DiagnosticUnderlineOk"] = { link = "NONE" },

	-- syntax
	["Comment"] = {
		fg = colors.comment --[[, italic = true ]],
	},
	["LspInlayHint"] = { link = "Comment" }, -- lsp内嵌颜色
	["Constant"] = { fg = colors.text },
	["String"] = { fg = colors.green },
	["Character"] = { fg = colors.orange },
	["Number"] = { fg = colors.red },
	["Boolean"] = { fg = colors.red },
	["Float"] = { link = "Number" },
	["Identifier"] = { fg = colors.text },
	["Function"] = { fg = colors.blue },
	["Statement"] = { link = "Identifier" },
	["Conditional"] = { fg = colors.purple },
	["Repeat"] = { fg = colors.purple },
	["Label"] = { fg = colors.yellow },
	["Operator"] = { fg = colors.delimiter },
	["Keyword"] = { fg = colors.purple },
	["Exception"] = { fg = colors.purple },
	["PreProc"] = { fg = colors.comment },
	["Type"] = { fg = colors.poggers },
	["StorageClass"] = { fg = colors.yellow },
	["Structure"] = { link = "Type" },
	["Typedef"] = { link = "Type" },
	["Special"] = { fg = colors.orange },
	["Delimiter"] = { fg = colors.delimiter },
	["Debug"] = { fg = colors.purple, italic = true },
	["debugPC"] = { link = "CursorLine" },
	["debugBreakpoint"] = { fg = colors.yellow, bold = true },
	["Todo"] = { bg = colors.blue, fg = colors.background, bold = true },

	-- tree-sitter
	["@variable"] = { link = "Identifier" },
	["@variable.builtin"] = { fg = colors.red, italic = true },
	["@variable.parameter"] = { link = "@variable" },
	["@variable.parameter.builtin"] = { link = "@variable.builtin" },
	["@variable.member"] = { fg = colors.lavender },
	["@module"] = { fg = colors.lavender },
	["@module.builtin"] = { fg = colors.red },
	["@string.documentation"] = { link = "@comment.documentation" },
	["@type.builtin"] = { link = "@type" },
	["@type.associated"] = { link = "@type" },
	["@type.enum"] = { fg = colors.orange },
	["@type.trait"] = { fg = colors.poggers, italic = true },
	["@attribute"] = { fg = colors.yellow },
	["@attribute.builtin"] = { link = "@attribute" },
	["@property"] = { link = "@variable.member" },
	["@function.builtin"] = { fg = colors.blue, italic = true },
	["@function.macro"] = { fg = colors.blue, bold = true },
	["@constructor"] = { link = "@type" },
	["@constructor.lua"] = { link = "@punctuation.bracket" },
	["@operator.try"] = { fg = colors.purple }, -- custom query for rust's `?`
	["@keyword.rust.unsafe"] = { fg = colors.red, bold = true },
	["@storageclass"] = { link = "StorageClass" },
	["@punctuation.special"] = { link = "@punctuation.bracket" },
	["@comment.documentation"] = { fg = colors.comment, italic = false },
	["@comment.error"] = { bg = colors.red, fg = colors.background, bold = true },
	["@comment.warn"] = { bg = colors.orange, fg = colors.background, italic = true },
	["@comment.todo"] = { link = "TODO" },
	["@comment.note"] = { link = "@comment.todo" },
	["@markup.quote"] = { fg = colors.foreground },
	["@markup.math"] = { fg = colors.foreground },
	["@markup.link"] = { fg = colors.red, italic = true },
	["@markup.raw"] = { fg = colors.delimiter },
	["@markup.list"] = { fg = colors.foreground_dark },
	["@markup.list.checked"] = { fg = colors.foreground },
	["@markup.list.unchecked"] = { fg = colors.delimiter },
	["@diff.plus"] = { link = "DiffAdd" },
	["@diff.minus"] = { link = "DiffDelete" },
	["@diff.delta"] = { link = "DiffChange" },
	["@tag"] = { link = "Delimiter" },
	["@tag.builtin"] = { link = "@tag" },
}

for group, attributes in pairs(highlight_groups) do
	vim.api.nvim_set_hl(0, group, attributes)
end
