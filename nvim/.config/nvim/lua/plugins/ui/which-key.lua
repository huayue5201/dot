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
			{ "<leader>c", group = "Close / Cleanup", icon = { icon = "󰅖 ", color = "red" } },
			{ "<leader>d", group = "Debug DAP", icon = { icon = "󰃤 ", color = "red" } },
			{ "<leader>D", group = "Docker / DevContainer", icon = { icon = "󰡨 ", color = "blue" } },
			{ "<leader>e", group = "Explorer", icon = { icon = "󰙅 ", color = "azure" } },
			{ "<leader>f", group = "Find / Replace", icon = { icon = "󰈞 ", color = "green" } },
			{ "<leader>F", group = "File operations", icon = { icon = "󰉋 ", color = "azure" } },
			{ "<leader>g", group = "Database (sqmeow)", icon = { icon = "󰆼 ", color = "green" } },
			{ "<leader>h", group = "Git / History (CodeDiff)", icon = { icon = "󰊢 ", color = "orange" } },
			{ "<leader>H", group = "Git / History (DiffBandit)", icon = { icon = "󰊢 ", color = "orange" } },
			{ "<leader>j", group = "Context / Jump", icon = { icon = "󰓩 ", color = "purple" } },
			{ "<leader>m", group = "TODO / Markdown", icon = { icon = "󰍔 ", color = "blue" } },
			{ "<leader>n", group = "Notes (Obsidian)", icon = { icon = "󰠮 ", color = "purple" } },
			{ "<leader>o", group = "Format / Align", icon = { icon = "󰉢 ", color = "cyan" } },
			{ "<leader>i", group = "Project info", icon = { icon = "󰋜 ", color = "azure" } },
			{ "<leader>r", group = "Refactor / Run / Toggle", icon = { icon = "󰐊", color = "green" } },
			{ "<leader>R", group = "REST requests (nurl)", icon = { icon = "󰖟 ", color = "cyan" } },
			{ "<leader>s", group = "Symbols / Query", icon = { icon = "󰅴 ", color = "yellow" } },
			{ "<leader>S", group = "Snippets", icon = { icon = "󰅩 ", color = "orange" } },
			{ "<leader>t", group = "Tests / Coverage", icon = { icon = "󰙨", color = "green" } },
			{ "<leader>w", group = "Windows", icon = { icon = "󰖲 ", color = "blue" } },
			{ "<leader>T", group = "Terminal (betterTerm)", icon = { icon = " ", color = "red" } },
			{ "<leader>x", group = "Clue marks", icon = { icon = "󱉷 ", color = "yellow" } },
			{ "<leader>y", group = "Copy", icon = { icon = "󰆏 ", color = "azure" } },
			{ "<leader>z", group = "Tools", icon = { icon = "󱁤 ", color = "grey" } },
			{ "<leader>b", group = "Buffers", icon = { icon = " ", color = "yellow" } },
			{ "<leader>l", group = "Tabs / Workspace", icon = { icon = "󱦞 ", color = "green" } },
			{ "<leader>u", group = "Undo / History", icon = { icon = "󰣜 ", color = "cyan" } },

			-- 非 leader 前缀分组：调试打印 (nvim-chainsaw)
			{ "g?", group = "Debug print (chainsaw)", icon = { icon = "󰹈 ", color = "orange" } },

			-- 二级分组
			{ "<leader>bs", group = "Sort" },
			{ "<leader>cs", group = "Swap files (swap)" },
			{ "<leader>dl", group = "Breakpoints / Images" },
			{ "<leader>dv", group = "DAP view / REPL" },
			{ "<leader>lt", group = "Tabs" },
			{ "<leader>lw", group = "Workspace" },
			{ "<leader>ls", group = "Sessions" },
			{ "<leader>ma", group = "Archived tasks" },
			{ "<leader>mf", group = "TODO files" },
			{ "<leader>mg", group = "Anchors / Git" },
			{ "<leader>ml", group = "Backlink marks" },
			{ "<leader>mt", group = "Task actions" },
			{ "<leader>mv", group = "View / Open" },
			{ "<leader>rS", group = "SnipRun run" },
			{ "<leader>rt", group = "Toggle / Reload" },
			{ "<leader>sa", group = "LSP symbols" },
			{ "<leader>sc", group = "LSP calls / ctags" },
			{ "<leader>ss", group = "Jump to symbol" },

			-- localleader 分组（<localleader> 没设过，就是默认的 \）
			-- 注意：which-key 会删掉「没有任何子映射」的分组节点，所以这里只登记
			-- 当前全局确实有按键的分组。以下这些不能写在这里：
			--   \c*  crates    —— 只在 toml buffer 里（map_filetype），全局树里没有
			--   \g*  grug-far —— 窗口内是插件自己注册的 buffer 键，且入口已挪到 <leader>f*
			--   \x*  quickfix —— 已不存在，quickfix/loclist 现在是单独的 \q / \l
			-- 同理 \q、\l、\Q 都是单键叶子，不构成分组。
			{ "<localleader>m", group = "Markmap mind map", icon = { icon = "󰈈 ", color = "green" } },
			{ "<localleader>r", group = "RustOwl", icon = { icon = "󱘗 ", color = "orange" } },
			{ "<localleader>s", group = "Save (save)", icon = { icon = "󰆓 ", color = "green" } },
			{ "<localleader>t", group = "Translate (translator)", icon = { icon = "󰗊 ", color = "cyan" } },
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

		hydra_trigger("<leader>wW", "<c-w>", "Window operations") -- 触发后：l/h/j/k 移动、s/v 分屏、o 关其他、= 均分…
		hydra_trigger("<leader>zz", "z", "Fold / Scroll") -- 触发后：a/ o/c 折叠、z/t/b 定位、R/M 全展/全折…
		-- 想再加就照抄一行，例如：
		-- hydra_trigger("<leader>]", "]", "下一个"); hydra_trigger("<leader>[", "[", "上一个")
	end,
}
