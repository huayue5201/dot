-- https://github.com/chaneyzorn/spellwand.nvim
--
-- 把 Neovim 原生 spell 包成 **in-process LSP**（纯 Lua，无外部二进制）：
--   判定仍走 vim.spell.check / spellbadword / spellsuggest → 词典、spellfile、
--   `spelllang=en_us,cjk` 的 cjk 语义全部沿用（见 lua/feat/spell.lua）；
--   出口换成 diagnostics + code action（「换成建议词」「加进 spellfile」）。
--
-- 配置**全部**写在这里（原来在 lsp/spellwand.lua，已删）：
--   插件自带 `lsp/spellwand.lua`，内容只有 cmd + settings(default_config)，它在 rtp 里
--   排在 ~/.config/nvim 之后，而 nvim 解析配置时按 rtp 顺序
--   `tbl_deep_extend('force')` 逐个合并同名 lsp/*.lua（runtime/lua/vim/lsp.lua:352-362）
--   → 我们自己 rtp 里的 lsp/spellwand.lua 会被插件的 default_config 反盖
--   （cond 变回「恒 true」，黑名单 *.todo.md 失效；max_errors 变 999 等）。
--   只有 `vim.lsp.config(name, cfg)` 的优先级高于 rtp 文件（合并链最后一项），
--   所以这份配置必须走 vim.lsp.config 注册，而不是靠 lsp/spellwand.lua。

-- 拼写诊断的文件名黑名单（basename glob）：随手清单 / 自动生成的文件不查
local SPELLWAND_IGNORE_FILES = {
	"*.todo.md",
	"*.TODO.md",
}

local function cond(bufnr)
	local name = vim.api.nvim_buf_get_name(bufnr)
	-- 黑名单：按 basename 匹配 glob（todo 之类随手清单不查拼写）
	local base = vim.fn.fnamemodify(name, ":t")
	for _, pat in ipairs(SPELLWAND_IGNORE_FILES) do
		if vim.fn.match(base, vim.fn.glob2regpat(pat)) >= 0 then
			return false
		end
	end
	-- 只读或超长文件跳过（spellwand 每 300ms 全 buffer 扫描）
	if name ~= "" and vim.fn.getfsize(name) > 200 * 1024 then
		return false
	end
	return vim.bo[bufnr].modifiable
end

return {
	"chaneyzorn/spellwand.nvim",
	config = function()
		-- FIX:(spellwand.nvim 多行 @spell 列号越界) 上游修复后删掉这一行 + lua/fix/spellwand_multiline_spell_offset.lua
		-- 是否已修：:FixStatus（lua/fix/init.lua 的守卫会盯着上游源码）
		require("fix.spellwand_multiline_spell_offset").install()

		vim.lsp.config("spellwand", {
			-- in-process：cmd 是函数，LSP 请求直接在 nvim 进程里分发
			cmd = function(dispatchers, config)
				return require("spellwand.lsp").create_rpc(dispatchers, config)
			end,
			-- 只管文本：不要加 lua/rust/python —— 代码里既没 @spell query 覆盖不到注释，
			-- 又会把标识符当正文扫，噪音大于收益
			filetypes = { "markdown", "text", "tex", "gitcommit", "rst", "asciidoc" },
			root_markers = { ".git" },
			single_file_support = true,
			settings = {
				spellwand = {
					cond = cond,
					max_errors = 200, -- 大文件早点停，够看就行
					-- 默认 SpellBad=WARN、SpellCap/SpellLocal=HINT，保留
					num_suggestions_in_diagnostics = 1, -- 诊断文案里带一个「did you mean」
					num_suggestions_in_code_action = 4,
					debounce_ms = 300,
				},
			},
		})
	end,
	-- 启动由 lua/lsp_ext 的 FileType 流程触发
}
