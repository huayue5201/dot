-- https://clangd.llvm.org/config
-- NOTE: https://github.com/clice-project/clice 候选lsp

return {
	cmd = {
		"clangd",
		"--clang-tidy",
		"--background-index", -- 启用后台索引
		"--offset-encoding=utf-8",
	},
	root_markers = {
		".clangd",
		".clang-tidy",
		".clang-format",
		"compile_commands.json",
		"compile_flags.txt",
		"configure.ac",
		".git",
		"STM32CubeMX", -- 添加 STM32CubeMX 文件夹
	},
	filetypes = { "c", "cpp", "h" }, -- 添加 .h 文件支持
	settings = {
		workspace = {
			didChangeWatchedFiles = {
				enabled = true, -- 必须是 boolean，"true" 字符串是非法配置
			},
		},
		-- 启用标准库索引
		index = {
			StandardLibrary = true, -- 启用标准库索引
			Background = "build", -- 允许值: Skip / Background / Build
			-- BackgroundIndex / BackgroundWait 不是 clangd 配置项（见本文件顶部的 CLI flag）
		},
	},
}
