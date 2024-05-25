-- https://github.com/jedrzejboczar/nvim-dap-cortex-debug

return {
	"jedrzejboczar/nvim-dap-cortex-debug",
	ft = "c",
	dependencies = "mfussenegger/nvim-dap",
	config = function()
		require("dap-cortex-debug").setup({
			debug = false, -- 是否记录调试消息
			-- cortex-debug 扩展的路径，支持 vim.fn.glob
			-- 默认会尝试猜测: mason.nvim 或 VSCode 扩展
			extension_path = nil,
			lib_extension = nil, -- 共享库的扩展名，尝试自动检测，例如在 unix 上是 'so'
			node_path = "node", -- node.js 可执行文件的路径
			dapui_rtt = true, -- 注册 nvim-dap-ui 的 RTT 元素
			-- :DapLoadLaunchJSON 为 C/C++ 注册 cortex-debug，设置为 false 禁用此功能
			dap_vscode_filetypes = { "c", "cpp" },
		})
	end,
}
