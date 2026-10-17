-- lua/lsp-config/icons.lua
---@brief LSP/诊断图标的唯一来源（statusline 与 sign 列共用）
-- VSCode 风格：统一用实心圆点，靠 Diagnostic{Error,Warn,Info,Hint} 颜色区分严重级别。
-- 用 nr2char 而不是字面量，避免源码/同步过程把私有区字形弄坏。
-- nf-fa-circle = U+F111，实心圆

return {
	ERROR = " ",
	WARN = " ",
	HINT = " ",
	INFO = " ",
}
