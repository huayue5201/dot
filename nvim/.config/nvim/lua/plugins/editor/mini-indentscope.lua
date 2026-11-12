-- https://github.com/nvim-mini/mini.nvim/blob/main/readmes/mini-indentscope.md
--
-- 只画「代码 buffer」的缩进导轨：终端 / quickfix / help / 各种面板（buftype ~= ""）
-- 以及不可编辑的 buffer 一律不画，filetype 黑名单再兜一层。
-- 留 mini 而不换 hlchunk 的原因：它只算光标所在 scope（O(scope)），
-- hlchunk 要按视口逐行重算，大项目里滚动会明显卡。

return {
	"nvim-mini/mini.indentscope",
	sem_version = "*",
	config = function()
		local ignore_ft = {
			tab_terminal = true,
			snacks_dashboard = true,
			snacks_picker = true,
			dashboard = true,
			alpha = true,
			lazy = true,
			mason = true,
			NvimTree = true,
			neo_tree = true,
			oil = true,
			trouble = true,
			prompt = true,
			tab_term_sidebar = true,
		}

		---@param bufnr integer
		---@return boolean
		local function drawable(bufnr)
			if not vim.api.nvim_buf_is_valid(bufnr) then
				return false
			end
			local bo = vim.bo[bufnr]
			return bo.buftype == "" and bo.modifiable and not ignore_ft[bo.filetype]
		end

		require("mini.indentscope").setup({
			-- 虚线导轨，和 ask-agent 面板里 running_line = "dash" 的虚线路径统一
			-- （纯实线 ¦ 会把动态路径衬得突兀）。用 ┊（light quadruple dash）。
			symbol = "┊",
			draw = {
				predicate = function(scope)
					if scope.body.is_incomplete then
						return false
					end
					return drawable(scope.buf_id)
				end,
			},
		})

		-- 说明：predicate 在每次 autodraw 前被调用，返回 false 时 mini 自己会
		-- 先 undraw_scope 再跳过，所以这里是「无状态」的：
		-- 不需要 vim.b.miniindentscope_disable，也不会留下无法恢复的脏标记。
		-- （OptionSet 对 Lua 侧 vim.bo.xxx = 赋值不触发，故那条路本来也不可靠。）
	end,
}
