local M = require("env.core")

M.load_env_on_startup()

vim.api.nvim_create_user_command("ChooseEnv", function()
	M.choose_env()
end, { desc = "选择当前项目的开发环境" })

vim.keymap.set("n", "<leader>en", "<cmd>ChooseEnv<cr>", { desc = "配置切换" })

return M
