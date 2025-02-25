-- https://git.sr.ht/~alphakeks/.dotfiles/tree/717cc8fc8f5b5cc10a30ae4dab6fa0a699e94e06/item/nvim/colors/dawn.lua
--- Name:        dawn
--- Description: The best colorscheme there is.
--- Author:      AlphaKeks <alphakeks@dawn.sh>
--- License:     GPL 3.0

vim.opt.background = "dark"
vim.g.colors_name = "dawn"

local colors = {
	poggers = "#7480c2", -- 柔和的蓝色，通常用于突出显示或强调文本（例如，当前模式指示器等）。
	background = "#11111b", -- 非常暗的灰色接近黑色，作为背景色，提供深色背景，凸显其他元素。
	shade = "#1e1e2e", -- 深灰色，带有蓝色调，适用于深色背景和阴影部分，增强深度感。
	comment = "#3c5e7f", -- 浅灰蓝色，通常用于代码中的注释部分，给人温和、冷静的感觉。
	delimiter = "#6c7086", -- 中性色，带有灰色调，通常用于分隔符、标点符号等。
	foreground_dark = "#313244", -- 深灰蓝色，适用于较暗文本或其他元素的前景色。
	foreground = "#585b70", -- 灰蓝色，比 `foreground_dark` 明亮，常用于主要文本部分。
	text = "#cdd6f4", -- 柔和的浅蓝色，用作普通文本内容，舒适易读。
	lavender = "#b4befe", -- 淡紫色，通常用于突出显示或强调文本，如特殊文本或标签。
	blue = "#89b4fa", -- 亮蓝色，常用于标识符、链接或强调文本，充满活力。
	green = "#a6e3a1", -- 柔和的绿色，常用于表示成功、正常状态或通过的部分。
	yellow = "#f9e2af", -- 温暖的黄色，常用于警告、提示或高亮部分。
	orange = "#fab387", -- 暖橙色，通常用于吸引注意，给人活跃、亲切的感觉。
	red = "#f38ba8", -- 柔和的粉红色，带有红色调，通常用于错误、警告或重要提示。
	purple = "#cba6f7", -- 柔和的紫色，常用于强调、标签、注释等部分，具有梦幻感。
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
	["LineNr"] = { fg = "#7a7f8d" },
	["CursorLineNr"] = { fg = "#c9d1d9" },
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
	-- ["WinBar"] = { fg = colors.yellow, bold = true }, -- 设置 winbar 默认颜色为橙色并加粗
	-- ["WinBarSpecial"] = { fg = colors.blue, bold = true }, -- 设置特殊目录为绿色并加粗
	-- ["WinBarSeparator"] = { fg = colors.poggers }, -- 设置分隔符颜色为灰色
	-- ["WinBarNC"] = { link = "WinBar" },

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
