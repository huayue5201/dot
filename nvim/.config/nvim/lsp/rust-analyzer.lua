-- https://rust-analyzer.github.io/book/index.html

return {
	cmd = {
		"rust-analyzer", -- 启动 rust-analyzer 的命令
	},
	root_markers = { "Cargo.toml" }, -- 根目录标识文件，通常是 `Cargo.toml`
	filetypes = { "rust" }, -- 支持的文件类型，这里只支持 `rust`
	single_file_support = true, -- 启用单文件支持，允许在没有 Cargo.toml 文件的情况下分析 Rust 文件
	settings = {
		["rust-analyzer"] = {
			showUnlinkedFileNotification = false,
			check = {
				command = "clippy",
				allTargets = false,
				noDefaultFeatures = true,
			},
			cargo = {
				buildScripts = {
					enable = true, -- 启用构建脚本支持
				},
				target = "thumbv7em-none-eabihf",
				noDefaultFeatures = true,
				-- features = "all", -- 启用所有 Cargo 特性
				-- extraArgs = {"--target","thumbv7em-none-eabi"}, -- 添加额外的命令行参数
			},
			imports = {
				granularity = {
					group = "module",
				},
				prefix = "self",
			},
			lens = {
				enable = true, -- 启用 CodeLens 功能，显示代码信息如函数调用等
				references = {
					adt = {
						enable = true,
					},
					enumVariant = {
						enable = true,
					},
					method = {
						enable = true,
					},
					trait = {
						enable = true,
					},
				},
			},
			procMacro = {
				enable = true, -- 如果你用了 `#[proc_macro]` 的库（如 `defmt-rtt`）
			},
		},
	},
}
