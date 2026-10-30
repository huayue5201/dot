-- https://github.com/folke/which-key.nvim

return {
	"folke/which-key.nvim",
	config = function()
		require("which-key").setup({
			preset = "helix",
			show_help = false,
			show_keys = false,
		})

		-- 给「前缀（分组）」本身加注释。不注册的话 which-key 只会显示成 `<leader>d +N`；
		-- 注册后按下前缀键会显示成龙分组名。group 也可以是 function 动态生成。
		local wk = require("which-key")
		wk.add({
			-- 一级分组
			{ "<leader>a", group = "AI / Agent", icon = { icon = "󰚩 ", color = "green" } },
			{ "<leader>c", group = "关闭 / 清理", icon = { icon = "󰅖 ", color = "red" } },
			{ "<leader>d", group = "调试 DAP", icon = { icon = "󰃤 ", color = "red" } },
			{ "<leader>D", group = "Docker / DevContainer", icon = { icon = "󰡨 ", color = "blue" } },
			{ "<leader>e", group = "资源管理器", icon = { icon = "󰙅 ", color = "azure" } },
			{ "<leader>f", group = "查找 / 替换", icon = { icon = "󰈞 ", color = "green" } },
			{ "<leader>g", group = "数据库 (sqmeow)", icon = { icon = "󰆼 ", color = "green" } },
			{ "<leader>h", group = "Git / 历史", icon = { icon = "󰊢 ", color = "orange" } },
			{ "<leader>j", group = "上下文 / 跳转", icon = { icon = "󰓩 ", color = "purple" } },
			{ "<leader>m", group = "TODO / Markdown", icon = { icon = "󰍔 ", color = "blue" } },
			{ "<leader>n", group = "笔记 (Obsidian)", icon = { icon = "󰠮 ", color = "purple" } },
			{ "<leader>o", group = "格式 / 对齐", icon = { icon = "󰉢 ", color = "cyan" } },
			{ "<leader>r", group = "运行 / 切换", icon = { icon = "󰐊", color = "green" } },
			{ "<leader>R", group = "REST 请求 (nurl)", icon = { icon = "󰖟 ", color = "cyan" } },
			{ "<leader>s", group = "符号 / 查询", icon = { icon = "󰅴 ", color = "yellow" } },
			{ "<leader>S", group = "代码片段", icon = { icon = "󰅩 ", color = "orange" } },
			{ "<leader>t", group = "测试 / 覆盖率", icon = { icon = "󰙨", color = "green" } },
			{ "<leader>w", group = "窗口", icon = { icon = "󰖲 ", color = "blue" } },
			{ "<leader>T", group = "终端 (betterTerm)", icon = { icon = " ", color = "red" } },
			{ "<leader>x", group = "线索标记", icon = { icon = "󱉷 ", color = "yellow" } },
			{ "<leader>y", group = "复制", icon = { icon = "󰆏 ", color = "azure" } },
			{ "<leader>z", group = "工具", icon = { icon = "󱁤 ", color = "grey" } },
			{ "<leader>b", group = "缓冲区", icon = { icon = " ", color = "yellow" } },
			{ "<leader>l", group = "标签页 / 工作区", icon = { icon = "󱦞 ", color = "green" } },
			{ "<leader>u", group = "撤销 / 历史", icon = { icon = "󰣜 ", color = "cyan" } },

			-- 非 leader 前缀分组：调试打印 (nvim-chainsaw)
			{ "g?", group = "调试打印 (chainsaw)", icon = { icon = "󰹈 ", color = "orange" } },

			-- 二级分组
			{ "<leader>bs", group = "排序" },
			{ "<leader>cs", group = "交换文件 (swap)" },
			{ "<leader>dl", group = "断点列表 / 图像" },
			{ "<leader>dv", group = "DAP 视图 / REPL" },
			{ "<leader>lt", group = "标签页" },
			{ "<leader>lw", group = "工作区" },
			{ "<leader>ls", group = "会话 (session)" },
			{ "<leader>ma", group = "归档任务" },
			{ "<leader>mf", group = "TODO 文件" },
			{ "<leader>mg", group = "锚点 / Git" },
			{ "<leader>ml", group = "双链标记" },
			{ "<leader>mt", group = "任务操作" },
			{ "<leader>mv", group = "查看 / 打开" },
			{ "<leader>rS", group = "SnipRun 运行" },
			{ "<leader>rt", group = "切换 / 重载" },
			{ "<leader>sa", group = "LSP 符号" },
			{ "<leader>sc", group = "LSP 调用 / ctags" },
			{ "<leader>ss", group = "跳转符号" },

			-- localleader 分组（<localleader> 没设过，就是默认的 \）
			-- 注意：which-key 会删掉「没有任何子映射」的分组节点，所以这里只登记
			-- 当前全局确实有按键的分组。以下这些不能写在这里：
			--   \c*  crates    —— 只在 toml buffer 里（map_filetype），全局树里没有
			--   \g*  grug-far —— 窗口内是插件自己注册的 buffer 键，且入口已挪到 <leader>f*
			--   \x*  quickfix —— 已不存在，quickfix/loclist 现在是单独的 \q / \l
			-- 同理 \q、\l、\Q 都是单键叶子，不构成分组。
			{ "<localleader>m", group = "Markmap 思维导图", icon = { icon = "󰈈 ", color = "green" } },
			{ "<localleader>r", group = "RustOwl", icon = { icon = "󱘗 ", color = "orange" } },
			{ "<localleader>s", group = "保存 (save)", icon = { icon = "󰆓 ", color = "green" } },
			{ "<localleader>t", group = "翻译 (translator)", icon = { icon = "󰗊 ", color = "cyan" } },
		})

		vim.keymap.set("n", "<leader>?", function()
			require("which-key").show({ global = false })
		end, { desc = "Buffer Local Keymaps (which-key)" })

		-- ── Hydra 模式 ────────────────────────────────────────────────
		-- which-key 的 hydra：按触发键后弹窗常驻，可连续执行该前缀下的动作，<esc> 退出。
		-- 会用 which-key 回放完整序列（如按 l → 执行 <c-w>l），所以触发键之后只按单键。
		--
		-- 注意：触发键不能直接绑成前缀本身（<c-w> / z / g? …）。因为前缀节点若同时是
		-- 真实映射，which-key 会当成普通映射执行而不是下钻（会触发递归）。所以用独立的触发键。
		local function hydra_trigger(lhs, prefix, desc)
			vim.keymap.set("n", lhs, function()
				require("which-key").show({ keys = prefix, loop = true })
			end, { desc = "Hydra: " .. desc })
		end

		hydra_trigger("<leader>wW", "<c-w>", "窗口操作") -- 触发后：l/h/j/k 移动、s/v 分屏、o 关其他、= 均分…
		hydra_trigger("<leader>zz", "z", "折叠 / 滚动") -- 触发后：a/ o/c 折叠、z/t/b 定位、R/M 全展/全折…
		-- 想再加就照抄一行，例如：
		-- hydra_trigger("<leader>]", "]", "下一个"); hydra_trigger("<leader>[", "[", "上一个")
	end,
}
