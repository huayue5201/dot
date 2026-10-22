-- https://github.com/akinsho/git-conflict.nvim
--
-- 冲突解决的按键分工（避免和 codediff 的 3 路视图搞混）：
--   工作区文件里（本插件，buffer-local）：co ours / ct theirs / cb both / c0 none / ]x [x
--   codediff 冲突视图内（它自己管）：<leader>co / <leader>ct / <leader>cb / <leader>cx

return {
	"akinsho/git-conflict.nvim",
	config = function()
		require("git-conflict").setup()

		-- 只在冲突文件里提示一次；解决冲突的统一入口是插件自己的 co/ct/cb/c0
		vim.api.nvim_create_autocmd("User", {
			pattern = "GitConflictDetected",
			callback = function()
				vim.notify(
					("检测到冲突：%s（co=ours  ct=theirs  cb=both  c0=none  ]x/[x 跳转）"):format(vim.fn.expand("<afile>")),
					vim.log.levels.WARN
				)
			end,
		})
	end,
}
