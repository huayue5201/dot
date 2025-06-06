-- https://clangd.llvm.org/config
-- NOTE:https://github.com/clice-project/clice 候选lsp

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
				enabled = "true",
			},
		},
		-- 启用标准库索引
		index = {
			StandardLibrary = "Yes", -- 启用标准库索引
			Background = "Build", -- 启用背景索引
			BackgroundIndex = "true", -- 确保启用完全背景索引
			BackgroundWait = "true", -- 等待索引完成
		},
	},
}
