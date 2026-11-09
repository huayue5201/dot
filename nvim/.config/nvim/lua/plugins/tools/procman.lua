-- https://github.com/Anderson-Vilela-op/procman.nvim
-- 进程/服务管理器：自动发现 package.json / Cargo.toml / go.mod / *.sln(x)，
-- 面板按 kind 分组启停服务、查看日志、显示 RSS；每个项目可用 `.procman.lua` 覆写
-- （`:ProcManEdit` 生成模板）。这里只用默认配置（自动发现已开启），
-- 项目特有的 service 放各自的 `.procman.lua`，不写进配置。

return {
	"Anderson-Vilela-op/procman.nvim",
	opts = {},
	config = function(_, opts)
		local procman = require("procman")
		procman.setup(opts)

		-- 插件是 eager 加载的，setup 时 root 默认是启动目录；这里让 root 跟随当前 cwd
		-- （配合 tab 工作区换目录），只在真的变了才重新发现，避免每次切目录都扫盘。
		local function sync_root()
			local cwd = vim.fn.getcwd()
			local config = require("procman.config")
			if config.options.root ~= cwd then
				config.options.root = cwd
				require("procman.process").reload()
			end
		end
		vim.api.nvim_create_autocmd("DirChanged", {
			group = vim.api.nvim_create_augroup("ProcManRoot", { clear = true }),
			callback = sync_root,
		})

		vim.keymap.set("n", "<leader>rp", function()
			sync_root()
			procman.toggle_panel()
		end, { desc = "Procman: 进程面板" })
		vim.keymap.set("n", "<leader>re", "<cmd>ProcManEdit<CR>", { desc = "Procman: 编辑 .procman.lua" })
	end,
}
