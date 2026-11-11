-- https://github.com/tailwindlabs/tailwindcss-intellisense
---@brief Tailwind（v3/v4）class 补全、hover 预览、诊断、CSS 变量跳转。
--- 安装：brew install tailwindcss-language-server（0.16.x 同时支持 v3 与 v4）
--- 与现有工具的边界：
---   * 只管 class 补全 / 校验；格式化仍交给 conform 的 prettier 或 biome。
---   * 与 superhtml（html）、emmet（缩写）、tsgo（tsx 类型）并行 attach 互不影响。
---   * cssConflict / invalidApply 之类的诊断是 warning 级别，不会污染 error 计数。
---
--- root 判定（不做「有 .git 就启」）：
---   1) 向上找到 tailwind.config.{js,ts,mjs,cjs,mts,cts} → 用其所在目录
---   2) v4 项目常常没有配置文件，改为找常见 CSS 入口，读开头 4KB 看有没有
---      `@import "tailwindcss"` / `@tailwind base` → 用该入口所在目录
---   3) 都不匹配就不启动（避免每个 npm 项目白起一个 node 进程）
local CONFIG_FILES = {
	"tailwind.config.js",
	"tailwind.config.ts",
	"tailwind.config.mjs",
	"tailwind.config.cjs",
	"tailwind.config.mts",
	"tailwind.config.cts",
}

-- v4 的 CSS 入口常见位置（相对 buffer 目录向上查找）
local CSS_ENTRIES = {
	"globals.css",
	"global.css",
	"app.css",
	"index.css",
	"main.css",
	"style.css",
	"styles.css",
	"tailwind.css",
	"input.css",
	"theme.css",
}

local function read_head(path)
	local fd = io.open(path, "r")
	if not fd then
		return ""
	end
	local head = fd:read(4096) or ""
	fd:close()
	return head
end

local function is_tailwind_entry(path)
	local head = read_head(path)
	return head:find("@import%s*[\"']tailwindcss", 1) ~= nil
		or head:find("@import%s*url%(%s*[\"']?tailwindcss", 1) ~= nil
		or head:find("@tailwind%s+base", 1) ~= nil
end

-- 注意：root_dir 的函数形式必须调 on_dir(root)，返回值会被忽略（见 :h lsp-root_dir()）；
-- 不调 on_dir 就等于该项目不启用本 server。
local function root_dir(bufnr, on_dir)
	local name = vim.api.nvim_buf_get_name(bufnr)
	local start = name ~= "" and vim.fs.dirname(name) or vim.fn.getcwd()

	local cfg = vim.fs.find(CONFIG_FILES, { path = start, upward = true, type = "file", limit = 1 })[1]
	if cfg then
		on_dir(vim.fs.dirname(cfg))
		return
	end

	for _, entry in ipairs(vim.fs.find(CSS_ENTRIES, { path = start, upward = true, type = "file", limit = 8 })) do
		if is_tailwind_entry(entry) then
			on_dir(vim.fs.dirname(entry))
			return
		end
	end
end

return {
	cmd = { "tailwindcss-language-server", "--stdio" },
	root_dir = root_dir,
	filetypes = {
		"html",
		"css",
		"scss",
		"less",
		"postcss",
		"javascript",
		"javascriptreact",
		"typescript",
		"typescriptreact",
		"vue",
		"svelte",
		"astro",
		"mdx",
		"templ",
		"heex",
	},
	settings = {
		tailwindCSS = {
			validate = true,
			-- 自定义 class 属性名（React/Vue 常见写法）
			classAttributes = { "class", "className", "class:list", "classList", "ngClass" },
			lint = {
				cssConflict = "warning",
				invalidApply = "error",
				invalidScreen = "error",
				invalidVariant = "error",
				invalidConfigPath = "error",
				invalidTailwindDirective = "error",
				recommendedVariantOrder = "warning",
			},
			-- 动态拼接的 class 用正则让 server 识别（如 cva/twMerge 的字符串参数）
			experimental = { classRegex = {} },
		},
	},
}
