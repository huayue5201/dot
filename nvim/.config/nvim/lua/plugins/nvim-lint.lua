-- https://github.com/mfussenegger/nvim-lint
-- 作用：给只有 tree-sitter/sqlfluff 的 SQL buffer 补上语法诊断。
-- 只启用了 sqlfluff，并且只保留解析错误（PRS），不刷风格类规则。
return {
	"mfussenegger/nvim-lint",
	event = { "BufReadPost", "BufNewFile" },
	config = function()
		local lint = require("lint")

		lint.linters_by_ft = {
			sql = { "sqlfluff" },
		}

		-- https://github.com/sqlfluff/sqlfluff
		-- 方言不写死：交给 sqlfluff 自己的配置解析链
		--   逐级向上找 .sqlfluff → ~/.config/sqlfluff/.sqlfluff → CLI --dialect
		-- 用 --stdin-filename 指向真实文件，sqlfluff 才会去该文件所在目录链找 .sqlfluff。
		--   * `--rules=PRS` 是 sqlfluff 唯一能「只留解析错误」的方式（PRS 不是
		--     真正的 rule，选择它等于规则集为空，parse error 始终会报）。
		--     sqlfluff 会在 stderr 打一行 "Tried to allowlist unknown rule
		--     references: ['PRS']" 警告，不影响 stdout 的 JSON 诊断，也不会被
		--     nvim-lint 展示（该 linter 内置 ignore_exitcode = true）。
		--   * 依赖 `sqlfluff` 可执行文件（uv tool install sqlfluff → ~/.local/bin）。
		lint.linters.sqlfluff.args = {
			"lint",
			"--format=json",
			"--rules=PRS",
			"--stdin-filename",
			function()
				return vim.api.nvim_buf_get_name(0)
			end,
			"-",
		}

		vim.api.nvim_create_autocmd({ "BufWritePost", "InsertLeave" }, {
			callback = function()
				lint.try_lint()
			end,
		})
	end,
}
