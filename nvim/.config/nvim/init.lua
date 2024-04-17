-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 模块列表
local modules = {
	"config.options", -- 加载基础配置
	"config.keymaps", -- 加载自定义键绑定
	"config.autocmds", -- 加载自动命令设置
	"config.lazy", -- 加载延迟加载配置
	"user.statusline", -- 加载自定义状态栏
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
