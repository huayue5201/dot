-- https://taplo.tamasfe.dev/

return {
	cmd = { "taplo", "lsp", "stdio" },
	filetypes = { "toml" },
	root_markers = {
		".git",
		"Cargo.toml",
		"pyproject.toml",
		"taplo.toml",
	},
	single_file_support = true, -- 支持单文件模式
	init_options = {
		-- 自动配置 workspace detection
		autoconfig = true,
	},
	settings = {
		taplo = {
			-- 禁用一些冗长的警告
			diagnostics = {
				enabled = true,
				warnings = {
					-- 关闭 detached 相关警告
					unused_entry = false,
				},
			},
			-- 自动加载配置
			configuration = {
				cache_path = nil, -- 不缓存配置
			},
			-- 文件关联
			schema = {
				catalogs = {},
				-- 为特定文件指定 schema
				associations = {
					["Cargo.toml"] = "https://taplo.tamasfe.dev/schema/cargo.json",
					["deno.json"] = "https://json.schemastore.org/deno.json",
				},
			},
		},
	},
}
