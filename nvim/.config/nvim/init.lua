-- https://github.com/neovim/neovim
-- https://github.com/neovim/neovim/releases/
-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 模块列表
local modules = {
	"basic.options", -- 基础配置
	"basic.keymaps", -- 自定义键绑定
	"basic.usercmds", -- 自动命令
	"basic.lazy", -- 插件管理
	"utils.statusline", -- 自定义状态栏
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

-- 开启lsp-servers
vim.lsp.enable({ "lua_ls", "clangd", "taplo" })
