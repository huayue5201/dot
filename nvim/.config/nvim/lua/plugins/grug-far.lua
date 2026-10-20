-- https://github.com/MagicDuck/grug-far.nvim
--
-- 键位分工（避免和全局分组互相遮蔽）：
--   <leader>f*       打开 grug-far，和 fff 的 ff/fg 同一组：查找 + 替换
--   <localleader>*   窗口内的操作，全部沿用插件默认（<localleader> = \）：
--                    \r 替换   \q 进快速修复   \s 同步全部   \l 同步当前行
--                    \c 关闭   \e 换引擎       \i 预览位置   \b 中止
--                    \t 历史   \j/\k 逐个应用  \w 显示完整命令  \x 换替换解释器
--   不再用 <leader>* 覆盖窗口内键位——那会把 <leader>r / <leader>c / <leader>s /
--   <leader>h / <leader>a 这些全局分组在该窗口里改掉（历史上 <leader>sa 就顶掉了
--   「保存全部」、<leader>ha 顶掉了 atlas）。

return {
	"MagicDuck/grug-far.nvim",
	event = "VeryLazy",
	config = function()
		require("grug-far").setup({
			helpLine = { enabled = false },
			showInputsTopPadding = false,
			showInputsBottomPadding = false,
		})

		local function open(opts)
			return function()
				require("grug-far").open(opts)
			end
		end

		-- 主入口：光标下单词预填，并直接跳到替换框（批量改名 / 替换的第一步）
		vim.keymap.set("n", "<leader>fr", function()
			local inst = require("grug-far").open({
				prefills = { search = vim.fn.expand("<cword>") },
			})
			inst:when_ready(function()
				inst:goto_input("replacement")
			end)
		end, { desc = "grug-far：替换光标下单词（全项目）" })

		-- 仅当前文件
		vim.keymap.set("n", "<leader>fR", function()
			require("grug-far").open({ prefills = { paths = vim.fn.expand("%") } })
		end, { desc = "grug-far：只替换当前文件" })

		-- AST 引擎（结构化替换）
		vim.keymap.set("n", "<leader>fa", open({ engine = "astgrep" }), { desc = "grug-far：AST 引擎搜索替换" })

		-- 可视选区范围
		vim.keymap.set({ "n", "x" }, "<leader>fi", open({ visualSelectionUsage = "auto-detect" }), {
			desc = "grug-far：在选区内搜索替换",
		})

		-- 切换已有实例（最省事的「呼出 / 收起」）
		vim.keymap.set("n", "<leader>fo", function()
			require("grug-far").toggle_instance({
				instanceName = "far",
				staticTitle = "Find and Replace",
			})
		end, { desc = "grug-far：呼出 / 收起实例" })

		-- 临时 buffer（关闭即删）
		vim.keymap.set("n", "<leader>ft", open({ transient = true }), { desc = "grug-far：临时窗口" })

		-- 用上一次搜索（@/）预填；配合 fr 形成「改一次 → 再改同类」的循环
		vim.keymap.set({ "n", "x" }, "<leader>f/", function()
			local search = vim.fn.getreg("/")
			if search and vim.startswith(search, "\\<") and vim.endswith(search, "\\>") then
				search = "\\b" .. search:sub(3, -3) .. "\\b"
			elseif search and vim.startswith(search, "\\V") then
				search = search:sub(3)
			end
			local inst = require("grug-far").open({ prefills = { search = search } })
			inst:when_ready(function()
				inst:goto_input("replacement")
			end)
		end, { desc = "grug-far：用上次搜索（@/）替换" })

		----------------------------------------------------------------------
		-- 窗口内只补插件没有的两个键位，其余全用插件默认（<localleader> 前缀）
		----------------------------------------------------------------------
		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("grug-far-keymap", { clear = true }),
			pattern = "grug-far",
			callback = function(args)
				-- 跳回搜索输入框
				vim.keymap.set("n", "<left>", function()
					require("grug-far").get_instance(args.buf):goto_first_input()
				end, { buffer = args.buf, desc = "grug-far：回到搜索框" })

				-- 切换字面匹配（默认的 \s 是 syncLocations，别占用）
				vim.keymap.set("n", "<localleader>F", function()
					local state = unpack(require("grug-far").get_instance(args.buf):toggle_flags({ "--fixed-strings" }))
					vim.notify("grug-far: --fixed-strings " .. (state and "ON" or "OFF"))
				end, { buffer = args.buf, desc = "grug-far：切换字面匹配" })
			end,
		})
	end,
}
