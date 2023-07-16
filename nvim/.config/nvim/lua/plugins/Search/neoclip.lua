-- https://github.com/AckslD/nvim-neoclip.lua

return {
	"AckslD/nvim-neoclip.lua",
	event = { "BufReadPost", "BufNewFile" },
	keys = {
		{ "<leader>fy", "<cmd>lua require('telescope').extensions.neoclip.default()<cr>", desc = "剪贴板记录" },
		{ "<leader>fr", "<cmd>lua require('telescope').extensions.macroscope.default()<cr>", desc = "宏历史记录" },
	},
	dependencies = {
		-- https://github.com/kkharji/sqlite.lua
		"kkharji/sqlite.lua",
		-- you'll need at least one of these
		"nvim-telescope/telescope.nvim",
		-- {'ibhagwan/fzf-lua'},
	},
	config = function()
		-- 过滤空白yanks
		local function is_whitespace(line)
			return vim.fn.match(line, [[^\s*$]]) ~= -1
		end

		local function all(tbl, check)
			for _, entry in ipairs(tbl) do
				if not check(entry) then
					return false
				end
			end
			return true
		end

		require("neoclip").setup({
			history = 1000,
			-- 使用kkharji/sqlite.lua持久记录剪贴板内容
			enable_persistent_history = true,
			-- 每次复制都永久记录
			continuous_sync = true,
			-- 类容格式
			content_spec_column = true,
			-- 剪切寄存器名称
			default_register = { '"', "*", "+" },
			-- 开启宏保存
			enable_macro_history = true,
			-- 宏使用的寄存器
			default_register_macros = "q",
			-- 不要存储空白yanks
			-- 过滤空白yanks
			filter = function(data)
				return not all(data.event.regcontents, is_whitespace)
			end,
		})
	end,
}
