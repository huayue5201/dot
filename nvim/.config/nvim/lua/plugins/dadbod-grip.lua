-- https://github.com/joryeugene/dadbod-grip.nvim
-- TODO: https://github.com/kopecmaciej/vi-sql.nvim
-- TODO: https://github.com/kndndrj/nvim-dbee

return {
	"joryeugene/dadbod-grip.nvim",
	event = "VeryLazy",
	config = function()
		require("dadbod-grip").setup({
			limit = 200, -- rows per page (default: 200)
			max_col_width = 60, -- truncate long cell values in the grid
			timeout = 30000, -- query timeout in milliseconds

			picker = "builtin", -- 'builtin' | 'telescope' | 'snacks'
			completion = true, -- false to use blink.cmp or nvim-cmp instead
			connections_path = nil, -- absolute path to shared connections.json

			pinned_max = nil,

			ai = {
				provider = "anthropic", -- 'anthropic' | 'openai' | 'gemini' | 'ollama'
				model = "claude-sonnet-4-6",
				api_key = nil, -- nil reads from env var; or 'env:VAR', 'cmd:...', direct string
				base_url = nil, -- override for Ollama or proxy endpoints
			},

			open_key = "<leader>db", -- key to open the grip workspace
		})

		-- 数据库连接
		vim.keymap.set("n", "<localleader>gc", "<cmd>GripConnect<cr>", {
			desc = "数据库连接",
			silent = true,
			noremap = true,
		})

		-- 数据网格
		vim.keymap.set("n", "<localleader>gr", "<cmd>Grip<cr>", {
			desc = "数据网格",
			silent = true,
			noremap = true,
		})

		-- 数据表
		vim.keymap.set("n", "<localleader>gt", "<cmd>GripTables<cr>", {
			desc = "数据表",
			silent = true,
			noremap = true,
		})

		-- 查询面板
		vim.keymap.set("n", "<localleader>gq", "<cmd>GripQuery<cr>", {
			desc = "查询面板",
			silent = true,
			noremap = true,
		})

		-- 数据库结构
		vim.keymap.set("n", "<localleader>gs", "<cmd>GripSchema<cr>", {
			desc = "数据库结构",
			silent = true,
			noremap = true,
		})

		-- 历史记录
		vim.keymap.set("n", "<localleader>gh", "<cmd>GripHistory<cr>", {
			desc = "历史记录",
			silent = true,
			noremap = true,
		})
	end,
}
