-- https://github.com/neovim/neovim
-- https://github.com/neovim/neovim/releases/
-- https://vim.rtorr.com/lang/zh_cn vim 操作手册
-- 启用 Lua 加载器以提高启动速度
vim.loader.enable()

-- 模块列表
local modules = {
	"basic.options", -- 基础配置
	"UI.colorscheme", -- 主题颜色
	"basic.keymaps", -- 自定义键绑定
	"basic.usercmds", -- 自动命令
	"basic.lazy", -- 插件管理
	"UI.statusline", -- 自定义状态栏
	-- "UI.winbar",
	"utils.largefile", -- 大文件优化
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
