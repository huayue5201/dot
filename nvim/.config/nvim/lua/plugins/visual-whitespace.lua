-- https://github.com/mcauley-penney/visual-whitespace.nvim
-- 选中文本时才显示空白字符（模仿 VSCode 的 renderWhitespace: selection）。
-- 需要 Neovim >= 0.12（本机 0.13-dev），老版本走 compat-v10 分支。

local api = vim.api

-- 图标色从当前主题推导：Normal 的 fg 往 bg 方向压到 25%，比 Comment 还暗一档，
-- 效果接近虚拟文本那种「有但不抢眼」。换主题后由 ColorScheme 自动重算。
local DIM = 0.68 -- 1 = 完全等于 bg（看不见），0 = 正文色

local function channel(color, shift)
	return math.floor(color / shift) % 0x100
end

local function mix(a, b)
	return math.floor(a + (b - a) * DIM + 0.5)
end

---@return integer|nil
local function icon_fg()
	local normal = api.nvim_get_hl(0, { name = "Normal", link = false })
	local bg, fg = normal.bg, normal.fg
	if not (type(bg) == "number" and type(fg) == "number") then
		return nil
	end
	local function blend(shift)
		return mix(channel(fg, shift), channel(bg, shift))
	end
	return blend(0x10000) * 0x10000 + blend(0x100) * 0x100 + blend(1)
end

local HL = "VisualNonText"

local function apply_hl()
	api.nvim_set_hl(0, HL, { fg = icon_fg() or "#3a3f4b" })
end

return {
	"mcauley-penney/visual-whitespace.nvim",
	config = function()
		require("visual-whitespace").setup({
			-- 沿用全局 listchars 的思路：空格 / Tab / nbsp 都抓
			match_types = {
				space = true,
				tab = true,
				nbsp = true,
				lead = false,
				trail = false,
			},
			-- 只给 fg，bg 留空 → 选区的 Visual 底色照旧透出来
			highlight = { fg = icon_fg() },

			-- 图标：想换成别的符号只改这里（都收在下面一张表里）
			list_chars = {
				space = "·", -- 空格 U+00B7
				tab = "↦", -- Tab
				nbsp = "␣", -- 不换行空格 U+2423
				lead = "‹", -- 行首空白（match_types.lead = false 时不生效）
				trail = "›", -- 行尾空白（match_types.trail = false 时不生效）
			},
			-- 行末换行符（按 fileformat 区分）
			fileformat_chars = {
				unix = "↲",
				mac = "←",
				dos = "↙",
			},
		})

		-- setup() 里写的 highlight 是静态的；这里跟主题联动
		apply_hl()
		local group = api.nvim_create_augroup("VisualWhitespaceHighlight", { clear = true })
		api.nvim_create_autocmd("ColorScheme", {
			group = group,
			callback = function()
				apply_hl()
			end,
		})

		vim.keymap.set({ "n", "v" }, "<leader>zb", function()
			require("visual-whitespace").toggle()
		end, { desc = "空白: 切换可视化空白字符" })
	end,
}
