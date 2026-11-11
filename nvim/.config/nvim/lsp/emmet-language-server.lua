-- https://github.com/olrtg/emmet-language-server
---@brief Emmet 缩写展开（`div.card>ul>li*3` → 完整标签）。
--- 安装：npm i -g @olrtg/emmet-language-server（brew 没有这个 formula）
--- 与现有工具的边界：
---   * 只提供 textDocument/completion，不格式化、不诊断 → 与 superhtml（html）、
---     tailwind（class 补全）、conform 的 prettier/biome 都不冲突，可以同时挂。
---   * 展开靠补全列表里插入，所以依赖 blink 的 lsp source（已默认开启）。
---   * 触发字符是缩写本身（无 triggerCharacters），在标签内/选择器位置才会出现候选。
--- 注：emmet 只在 markup / stylesheet 场景有意义，别挂到普通文本 ft 上。

return {
	cmd = { "emmet-language-server", "--stdio" },
	filetypes = {
		"html",
		"css",
		"scss",
		"sass",
		"less",
		"postcss",
		"javascriptreact",
		"typescriptreact",
		"vue",
		"svelte",
		"astro",
		"eruby",
		"htmldjango",
		"pug",
		"templ",
	},
	root_markers = { "package.json", ".git" },
	single_file_support = true,
	init_options = {
		-- 默认 always：在 html/css/jsx 里输入缩写即出展开项
		showExpandedAbbreviation = "always",
		showAbbreviationSuggestions = true,
		-- 走补全而不是 snippet，避免和 blink 的 snippet 展开抢 <Tab>
		showSuggestionsAsSnippets = false,
		preferences = {},
	},
}
