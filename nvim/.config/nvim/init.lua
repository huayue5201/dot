vim.loader.enable()
-- 加载基本配置
require("config.options")
-- lazy加载
require("config.lazy")
-- 自定义函数和自定义按键映射
vim.api.nvim_create_autocmd("User", {
   pattern = "VeryLazy",
   callback = function()
      require("config.autocmds")
      require("config.keymaps")
   end,
})
