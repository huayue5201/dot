-- https://github.com/jmbuhr/otter.nvim
--
-- 注意：加载器是 eager 的，插件一启动就加载，此时当前 buffer 还不是 markdown。
-- 所以 activate() 不能无条件调用（否则会报 "No treesitter parser found for current
-- buffer. Can't activate."），改成挂在宿主 filetype 上，语义和以前 `ft = ...` 懒加载一致。

local host_fts = { "markdown", "quarto", "rmd" }

return {
	"jmbuhr/otter.nvim",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	config = function()
		local otter = require("otter")
		otter.setup()

		-- 嵌入语言：markdown 代码块里要激活的语言
		-- 参数：languages, completion, diagnostics, tsquery
		local function activate()
			otter.activate({ "python", "lua", "rust" }, true, false, nil)
		end

		vim.api.nvim_create_autocmd("FileType", {
			pattern = host_fts,
			group = vim.api.nvim_create_augroup("OtterActivate", { clear = true }),
			callback = activate,
			desc = "markdown 等宿主文件里激活嵌入语言",
		})

		if vim.tbl_contains(host_fts, vim.bo.filetype) then
			activate()
		end
	end,
}
