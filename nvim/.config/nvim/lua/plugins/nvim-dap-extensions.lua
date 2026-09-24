-- 自定义 DAP 断点扩展（本地插件）
-- 提供 function / data / instruction(硬件) / column 四类断点，以及
-- 与 nvim-dap-view 断点视图的集成（dap-extensions.integration）。

return {
	dir = "~/neovim-plugins/nvim-dap-extensions",
	name = "nvim-dap-extensions",
	dev = true,
	lazy = true,
	-- 运行时依赖 nvim-dap（在 setup() / 同步时使用）。
	-- 本插件作为 nvim-dap 和 nvim-dap-view 的依赖被加载，因此无需单独声明 event。
}
