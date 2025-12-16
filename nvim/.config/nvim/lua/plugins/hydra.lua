-- https://github.com/nvimtools/hydra.nvim

return {
	"nvimtools/hydra.nvim",
	config = function()
		local Hydra = require("hydra")

		Hydra({
			name = "Side scroll",
			mode = "n",
			body = "z",
			heads = {
				{ "h", "5zh" },
				{ "l", "5zl", { desc = "←/→" } },
				{ "H", "zH" },
				{ "L", "zL", { desc = "half screen ←/→" } },
			},
		})

		-- 窗口管理 Hydra
		Hydra({
			name = "Window Management",
			mode = "n", -- 普通模式
			body = "<C-w>", -- 进入 Hydra 的触发键
			hint = [[
  窗口管理:
  移动:   _h_ ←   _j_ ↓       _k_ ↑   _l_ →
  调整:   _H_ ←缩小宽度     _L_ →增加宽度
          _J_ ↓增加高度     _K_ ↑缩小高度
  分屏:   _s_ 水平分屏      _v_ 垂直分屏
  管理:   _c_ 关闭窗口      _o_ 只保留当前
  退出:   _q_
      ]],
			config = {
				color = "red", -- pink 模式允许外键继续生效
				invoke_on_body = true,
			},
			heads = {
				-- 移动窗口
				{ "h", "<C-w>h" },
				{ "j", "<C-w>j" },
				{ "k", "<C-w>k" },
				{ "l", "<C-w>l" },

				-- 调整大小
				{ "H", "<C-w><" },
				{ "L", "<C-w>>" },
				{ "J", "<C-w>+" },
				{ "K", "<C-w>-" },

				-- 分屏
				{ "s", "<C-w>s" },
				{ "v", "<C-w>v" },

				-- 管理窗口
				{ "c", "<C-w>c" },
				{ "o", "<C-w>o" },

				-- 退出 Hydra
				{ "q", nil, { exit = true } },
				{ "<esc>", nil, { exit = true } },
			},
		})
	end,
}
