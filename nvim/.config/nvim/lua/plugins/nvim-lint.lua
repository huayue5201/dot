-- https://github.com/mfussenegger/nvim-lint

return {
	"mfussenegger/nvim-lint",
	ft = "makefile",
	config = function()
		local lint = require("lint")
		lint.linters_by_ft = {
			makefile = { -- 根据文件类型设置linter
				cmd = "checkmake", -- 使用checkmake命令进行检查
				stdin = false, -- 不从stdin提供内容
				args = {}, -- 参数列表
				stream = "stdout", -- 输出流设置为stdout
				ignore_exitcode = false, -- 非0退出代码被认为是错误
				parser = function(output, bufnr) -- 解析函数
					local diagnostics = {}
					for line in vim.gsplit(output, "\n") do
						local rule, desc, line_number = line:match("%s*(%w+)%s+(.+)%s+(%d+)")
						if rule and desc and line_number then
							table.insert(diagnostics, {
								lnum = tonumber(line_number) + 1, -- Neovim的行号从1开始
								col = 1,
								severity = vim.lsp.protocol.DiagnosticSeverity.Error,
								message = string.format("[%s] %s", rule, desc),
							})
						end
					end
					return {
						diagnostics = diagnostics,
						-- 可以在此处添加其他返回值，如warnings、info等
					}
				end,
			},
		}

		vim.api.nvim_create_autocmd({ "BufWritePost" }, {
			callback = function()
				require("lint").try_lint()
			end,
		})
	end,
}
