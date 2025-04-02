-- https://rust-analyzer.github.io/

return {
	cmd = {
		"rust-analyzer",
	},
	root_markers = { "Cargo.toml" },
	filetypes = { "rust" },
	single_file_support = true, -- 启用单文件支持
	settings = {
		["rust-analyzer"] = {
			-- 导入设置
			imports = {
				granularity = {
					-- 设置为 module 表示按模块粒度进行导入（而不是按函数粒度）
					group = "module",
				},
				-- 设置导入的前缀
				prefix = "self", -- 导入时使用 `self` 前缀
			},
			lens = {
				enable = true, -- 启用 CodeLens
			},
			-- cargo 设置
			cargo = {
				-- 从 cargo check 加载输出目录，以加速 Rust 项目分析
				loadOutDirsFromCheck = true,

				-- 禁用自动运行构建脚本
				runBuildScripts = false,

				-- 启用构建脚本的支持
				buildScripts = {
					enable = true, -- 启用 Rust 构建脚本
				},
			},
			-- 宏支持设置
			procMacro = {
				-- 启用过程宏支持（如 `#[derive(...)]` 语法支持）
				enable = true,
			},
		},
	},
}
