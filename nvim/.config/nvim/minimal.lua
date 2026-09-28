--[[ minimal.lua —— 隔离排查 fff.nvim 的 bug（手动排查用）
--
-- 用法：
--   1) 先 cd 到一个真实的 git 仓库（fff 需要索引 cwd）
--   2) nvim --clean -u ~/.config/nvim/minimal.lua
--
-- 这是一个「独立配置」：
--   - 不会加载你日常的 ~/.config/nvim/init.lua
--   - 不会加载 lua/plugins/ 里的其它插件
--   - 只加载下面 PLUGINS 里列出的插件
--
-- 排查思路（核心）：
--   A. 只用 fff 跑一遍复现步骤
--        能复现   → 排除你自己的配置，是 fff 自身（或它依赖）的问题
--        不能复现 → 说明是你主配置里别的插件/配置和 fff 冲突
--   B. 冲突时，把可疑插件一个个从下面「二分区」加回来，看哪一步开始复现
--
-- fff 常用排查命令：
--   :FFFHealth     健康检查（picker / 可选依赖 / DB 连接）
--   :FFFOpenLog    打开日志（~/.local/state/nvim/log/fff.log）
--   :FFFScan       强制重新扫描
--   :FFFClearCache [all|frecency|files]  清缓存
--]]

-- 1. 复用本机已装的 lazy.nvim（避免重新 clone）
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	vim.fn.system({
		"git", "clone", "--filter=blob:none",
		"https://github.com/folke/lazy.nvim.git", lazypath,
	})
end
vim.opt.runtimepath:prepend(lazypath)

-- 与主配置保持一致的前缀键
vim.g.mapleader = " "

-- 2. 要加载的插件
local plugins = {
	{
		-- 上游已把仓库从 fff.nvim 改名为 fff（主配置已迁移到新名）
		"dmtrKovalenko/fff",
		lazy = false, -- fff 自己懒初始化
		build = function()
			require("fff.download").download_or_build_binary()
		end,
		-- 与主配置 lua/plugins/fff.lua 里的 setup 保持一致
		opts = {
			debug = { enabled = true, show_scores = true },
		},
		keys = {
			{ "<leader>ff", function() require("fff").find_files() end, desc = "FFFind files" },
			{ "<leader>fg", function() require("fff").live_grep() end, desc = "LiFFFe grep" },
			{
				"<leader>fz",
				function() require("fff").live_grep({ grep = { modes = { "fuzzy", "plain" } } }) end,
				desc = "Live fffuzy grep",
			},
			{ "<leader>fc", function() require("fff").live_grep({ query = vim.fn.expand("<cword>") }) end, desc = "Search current word" },
		},
	},

	-- 3. 二分区：fff 单独跑不能复现时，从下面逐个取消注释加回来
	--    （按怀疑程度排序，picker / 补全 / 图标类最可疑）
	-- { "nvim-tree/nvim-web-devicons" },
	-- { "saghen/blink.cmp", opts = {} },
	-- { "nvim-lua/plenary.nvim" },
	-- { "MeanderingProgrammer/render-markdown.nvim", opts = {} },
	-- { "esmuellert/codediff.nvim" },
	-- { "folke/snacks.nvim", opts = {} },
}

require("lazy").setup(plugins, {
	defaults = { lazy = false }, -- 复现环境全部立即加载，避免懒加载时序掩盖 bug
	install = { missing = true },
	checker = { enabled = false },
})

-- 4. 复现区：把触发 bug 的具体步骤写在这里（命令 / 按键 / 直接调 API）
--    例：
--    vim.keymap.set("n", "<F5>", function()
--      require("fff").find_files()
--    end, { desc = "复现操作" })
--    或者用 :FFFOpenLog 看日志，:FFFHealth 看环境

-- 5. 启动提示 + 已加载插件数（确认环境干净）
vim.api.nvim_create_autocmd("VimEnter", {
	callback = function()
		local stats = require("lazy").stats()
		vim.notify(
			string.format("minimal.lua 已加载（fff 隔离环境）：插件 %d/%d。:FFFHealth / :FFFOpenLog 排查", stats.loaded, stats.count),
			vim.log.levels.INFO
		)
	end,
})
