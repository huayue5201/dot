-- Rust 相关配置
vim.g.rustfmt_autosave = 1 -- 启用保存时自动格式化
vim.g.rustfmt_emit_files = 1 -- 启用生成格式化后的文件
vim.g.rust_recommended_style = 1 -- 启用推荐的代码风格
vim.g.rust_set_conceallevel = 1 -- 启用语法隐藏（如 `->` 显示为 →）
vim.g.rust_fold = 1 -- 启用代码折叠

-- Syntastic 配置（语法检查）
vim.g.syntastic_rust_cargo_checker = 1 -- 启用 cargo 检查
vim.g.syntastic_rust_rustc_checker = 1 -- 启用 rustc 检查
vim.g.syntastic_extra_filetypes =
	vim.tbl_extend("keep", vim.g.syntastic_extra_filetypes or {}, { rust = { "cargo", "rustc" } })
