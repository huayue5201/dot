-- https://github.com/zuqini/zpack.nvim
-- 插件管理完全走 Neovim 自带的 vim.pack：安装 / 更新 / 锁文件 / 版本都由内核负责，
-- zpack 只是在其上加了一层懒加载与 lazy.nvim 风格声明式 spec（`:ZPack` 命令）。

-- 锁文件放到 data 目录，避免污染配置仓库。必须在第一次 vim.pack 调用之前设置。
if vim.fn.exists("+packlockfile") == 1 then
	vim.o.packlockfile = vim.fs.joinpath(vim.fn.stdpath("data"), "nvim-pack-lock.json")
end

-- 用原生 vim.pack 安装 zpack 自身
vim.pack.add({ "https://github.com/zuqini/zpack.nvim" })

require("zpack").setup({
	cmd_name = "ZPack", -- :ZPack update | clean | restore | build | load | delete | sync | reload
	defaults = { confirm = false }, -- 非交互安装，等价于原先 lazy.nvim 的无提示行为
	spec = {
		{ import = "plugins" },
	},
})

-- dir = "~/neovim-plugins/*" 的本地插件：vim.pack 会 clone 一份副本，
-- 改为手动触发同步（<leader>zp 或 :PackLocalSync），不阻塞启动。
require("core.pack_local").setup()
