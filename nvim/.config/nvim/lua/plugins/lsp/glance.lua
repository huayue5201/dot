-- https://github.com/DNLHC/glance.nvim
-- LSP peek 预览：definitions / references / implementations / type_definitions 在一个浮窗里
-- 预览后再跳，不必离开当前上下文（VSCode 的 peek 同款）。浮窗内可编辑。
--
-- 映射放在 LSP 惯用的 gr 前缀下，和本配置已有的 gro/grx/grd/grD（lsp_ext/keys.lua:14-19）、
-- gra（tiny-code-action）、内建的 grn（rename）保持同一家族。
--
-- 关键约定：**不占用 Neovim 内建的 LSP 映射**（grr/gri/grt/grn/gra 原样保留，仍「直接跳」）。
-- glance 一律用 gr + 大写变体（等价于「同一动作的预览版」），小写保持原生行为：
--   grP definitions / grR references / grI implementations / grT type_definitions
-- definitions 不用 grD：grD 已被 lsp_ext 的「workspace diagnostics」占用（grd 是 buffer
-- diagnostics），所以用 grP（P = peek）。
--
-- 浮窗内映射沿用插件默认值（语义已经对齐：j/k 上下、s/v/t 分屏/new tab、<CR> 跳、q 关）。

return {
	"DNLHC/glance.nvim",
	config = function()
		require("glance").setup({
			height = 18,
			-- 父窗口够宽就嵌在父窗口里预览（保持上下文），太窄才浮出来
			detached = function(winid)
				return vim.api.nvim_win_get_width(winid) < 100
			end,
			preserve_win_context = true,
			preview_win_opts = { cursorline = true, number = true, wrap = true },
			list = { position = "right", width = 0.33 },
			folds = { folded = true },
		})

		local function glance(method)
			return function()
				vim.cmd("Glance " .. method)
			end
		end

		vim.keymap.set("n", "grP", glance("definitions"), { silent = true, desc = "Glance: 预览定义" })
		vim.keymap.set("n", "grR", glance("references"), { silent = true, desc = "Glance: 预览引用" })
		vim.keymap.set("n", "grI", glance("implementations"), { silent = true, desc = "Glance: 预览实现" })
		vim.keymap.set("n", "grT", glance("type_definitions"), { silent = true, desc = "Glance: 预览类型定义" })
	end,
}
