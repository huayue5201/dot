-- https://github.com/neovim/neovim
-- https://github.com/neovim/neovim/releases/
-- https://vim.rtorr.com/lang/zh_cn vim 操作手册
-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 设置前置按键
vim.g.mapleader = vim.keycode("<space>")
vim.keymap.set({ "n", "v" }, "<space>", "<Nop>", { silent = true })

-- 模块列表
local modules = {
	"basic.lazy", -- 插件管理
	"statusline", -- 自定义状态栏
}

-- 加载模块
for _, module in ipairs(modules) do
	local ok, module_func = pcall(require, module)
	if ok and type(module_func) == "function" then
		module_func()
	elseif not ok then
		print("加载", module, "时发生错误:", module_func)
	end
end
