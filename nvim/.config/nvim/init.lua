-- https://github.com/neovim/neovim
-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 模块列表
local modules = {
	"options", -- 基础配置
	"keymaps", -- 自定义键绑定
	"autocmds", -- 自动命令
	"user.lazy", -- 插件管理
	"user.statusline", -- 自定义状态栏
	"user.largefile", -- 优化大文件打开性能
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
