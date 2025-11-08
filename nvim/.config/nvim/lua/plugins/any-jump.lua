-- https://github.com/pechorin/any-jump.vim

return {
	"pechorin/any-jump.vim",
	event = "VeryLazy", -- 延迟加载，保证启动速度
	dependencies = {
		-- 必须安装 ripgrep 或 ag 作为后端搜索工具
	},
	config = function()
		-- ===================== 基本配置 =====================
		-- 是否在跳转后自动聚焦到预览窗口
		vim.g.any_jump_preview = 1
		-- 设置搜索结果窗口显示的行数
		vim.g.any_jump_window_preview_lines = 10
		-- 是否在跳转前显示搜索结果列表
		vim.g.any_jump_show_prompt = 1
		-- 忽略某些文件类型
		vim.g.any_jump_ignore_filetypes = { "markdown", "txt", "help" }

		-- ===================== 键位映射 =====================
		local opts = { noremap = true, silent = true }

		-- 跳转到定义 / 引用
		vim.api.nvim_set_keymap("n", "<leader>j", "<cmd>AnyJump<CR>", opts)
		vim.api.nvim_set_keymap("v", "<leader>j", "<cmd>AnyJump<CR>", opts)

		-- 返回上一次跳转位置
		vim.api.nvim_set_keymap("n", "<leader>ab", "<cmd>AnyJumpBack<CR>", opts)

		-- 打开上一次关闭的搜索结果
		vim.api.nvim_set_keymap("n", "<leader>al", "<cmd>AnyJumpLastSearch<CR>", opts)
	end,
}
