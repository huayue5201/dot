-- 创建一个名为 M 的模块
local M = {}

-- 设置 Clangd 的配置
M.setupClangd = function()
	require("lspconfig").clangd.setup({
		cmd = { "clangd", "--background-index" }, -- 使用 clangd 命令，并启用后台索引
		filetypes = { "c", "cpp", "objc", "objcpp" }, -- 文件类型
		init_options = {
			clangdFileStatus = true, -- 启用 clangd 文件状态
			usePlaceholders = true, -- 使用占位符
			completeUnimported = true, -- 自动完成未导入的内容
			semanticHighlighting = true, -- 启用语义高亮
			format = {
				enable = true, -- 启用格式化
				format = "file", -- 格式化方式为文件级别
				-- style = "Google", -- 格式化样式为 Google 风格（可选）
			},
			embeddings = {
				Enable = true, -- 启用嵌入式（可选）
			},
			diagnostic = { enable = false }, -- 禁用错误检查
		},
	})
end

return M -- 返回模块 M
