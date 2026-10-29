-- https://github.com/gbprod/yanky.nvim
-- 剪贴板环（yank ring）：yank/delete 入环，粘贴后可循环取环里更旧的内容。
--
-- 键位策略：不接管原生 p / P。
--   * p / P 保持 Neovim 原生行为（多光标、原生寄存器的语义都不会被改）
--   * <leader>p / <leader>P 走 yanky 的 put：进入环并把粘贴目标高亮出来
--   * ]y / [y 在「刚用 yanky 粘贴过」之后循环更旧/更新的一条
-- 不用 <C-n>/<C-p>（insert 里是补全），也不占 ]p / [p（Vim 内建「粘贴并按 indent 调整」）。
-- 不启用 picker（YankyRingHistory 需要 telescope/snacks），选历史用现有 fff/quicker。

return {
	"gbprod/yanky.nvim",
	config = function()
		local yanky = require("yanky")

		yanky.setup({
			ring = {
				-- 环的容量；超出后丢最旧的一条
				history_length = 100,
				-- "shada"：环跟着 Neovim 自己的 shada 落盘，不额外产生文件、无 fsync；
				-- 想完全不持久化就换成 "memory"
				storage = "shada",
				-- delete/change 引起的编号寄存器位移也同步进环，和原生行为一致
				sync_with_numbered_registers = true,
				-- 黑洞寄存器不入环
				ignore_registers = { "_" },
				-- 循环时不改写编号寄存器：环里翻动不会污染 "1~"9 的历史
				update_register_on_cycle = false,
				-- "update"：buffer 一被改动就结束本次循环（避免把改过的文本又覆盖回去）
				cancel_event = "update",
			},
			system_clipboard = {
				-- 与 clipboard=unnamedplus 的 + / * 同步，环里不会只有一份副本
				sync_with_ring = true,
			},
			highlight = {
				-- 粘贴后高亮刚插入的那一段（命名空间 yanky.put，高亮组 YankyPut，默认链到 Search）
				on_put = true,
				-- yank 时闪一下高亮（YankyYanked）
				on_yank = true,
				-- 高亮持续时长（毫秒）
				timer = 500,
			},
			preserve_cursor_position = {
				-- 稳定光标：yank 后不把光标跳到选区起点，留在原位置
				enabled = true,
			},
			textobj = {
				-- 依赖下面的 iy 映射（对「上一次环粘贴的范围」做 textobj）；关掉则 last_put() 只提示不动作
				enabled = true,
			},
		})

		-- 粘贴：走 yanky 的 put，才会进环 + 打高亮
		vim.keymap.set({ "n", "x" }, "<leader>p", function()
			yanky.put("p", vim.fn.mode() == "x")
		end, { desc = "环粘贴: 光标后" })

		vim.keymap.set({ "n", "x" }, "<leader>P", function()
			yanky.put("P", vim.fn.mode() == "x")
		end, { desc = "环粘贴: 光标前" })

		-- 循环：只在刚做过一次环粘贴后有效；否则安静地什么也不做，避免每次 INFO 提示刷屏
		local function cycle(direction)
			return function()
				if yanky.can_cycle() then
					yanky.cycle(direction)
				end
			end
		end

		vim.keymap.set("n", "]y", cycle(yanky.direction.FORWARD), { desc = "环粘贴: 上一条（更旧）" })
		vim.keymap.set("n", "[y", cycle(yanky.direction.BACKWARD), { desc = "环粘贴: 下一条（更新）" })

		-- iy = 「上一次环粘贴进来的那段文本」的 textobj：viy 选中它、diy/yiy/ciy 对它做操作。
		-- iy 不是任何内建 textobj（内建只有 iw/ip/is/ib/it/i(…等），无冲突。
		-- o 模式需要手动把待决 operator 作用到选中的区域上：last_put 内部会切到 visual，
		-- 而 visual 一度会丢掉待决 operator（不然 diy 什么也不会删）。
		vim.keymap.set({ "o", "x" }, "iy", function()
			local operator = vim.v.operator
			-- "ayiy 这类寄存器前缀在退出 operator-pending 后会丢，先记下来再自己补
			local register = vim.v.register
			if operator and operator ~= "" then
				-- 先退出 operator-pending，否则 visual 选区会把「待决 operator 的起点」当成锚点
				pcall(vim.api.nvim_feedkeys, vim.keycode("<Esc>"), "nx", false)
			end
			require("yanky.textobj").last_put()
			if operator and operator ~= "" then
				-- 用 normal! 而不是 feedkeys：映射内部再排队按键会重入事件循环，且 multi-char operator
				-- （如 g~ / gu）在 feedkeys 下会被拆成两步
				local prefix = (register and register ~= "" and register ~= '"') and register or ""
				pcall(vim.cmd, "normal! " .. prefix .. operator)
			end
		end, { desc = "环粘贴范围 textobj" })
	end,
}
