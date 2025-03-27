-- https://chatgpt.com/c/67e46a5b-e5c0-800d-95c5-989cbf5f5cd0

return {
	"github/copilot.vim",
	cmd = "Copilot",
	event = "BufWinEnter",
	init = function()
		vim.g.copilot_no_maps = true -- 禁用 Copilot 默认的按键映射
	end,
	config = function()
		-- Block the normal Copilot suggestions
		vim.api.nvim_create_augroup("github_copilot", { clear = true }) -- 创建一个新的自动命令组，名为 "github_copilot"

		-- 为文件类型和缓冲区卸载事件设置自动命令
		vim.api.nvim_create_autocmd({ "FileType", "BufUnload" }, {
			group = "github_copilot", -- 使用刚刚创建的命令组
			callback = function(args)
				vim.fn["copilot#On" .. args.event]() -- 调用 Copilot 的事件处理函数
			end,
		})

		-- 初始化 Copilot 的文件类型检测功能
		vim.fn["copilot#OnFileType"]()
	end,
}
