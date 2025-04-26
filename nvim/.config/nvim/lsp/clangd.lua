-- https://clangd.llvm.org/config

return {
	cmd = {
		"clangd",
		"--clang-tidy",
		"--background-index",
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
}
