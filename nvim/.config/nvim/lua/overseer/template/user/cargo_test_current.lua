-- cargo 运行当前光标所在的测试
-- 用法：在测试函数内按 :OverseerRun，选 "cargo test (当前测试)"
return {
	name = "cargo test (当前测试)",
	builder = function()
		-- 优先从当前行提取 `fn <测试名>`，光标不必精确停在函数名上
		local line = vim.api.nvim_get_current_line()
		local name = line:match("fn%s+([%w_]+)")
		if not name then
			-- fallback：取光标下的词
			name = vim.fn.expand("<cword>")
		end
		return {
			cmd = { "cargo", "test", name },
			components = { "on_output_quickfix", "default" },
		}
	end,
	condition = {
		filetype = { "rust" },
	},
}
