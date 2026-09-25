-- cargo 运行当前模块的所有测试
-- 用法：光标在某个 `mod xxx` 声明或其模块体内部任意位置，
--       按 :OverseerRun 选 "cargo test (当前模块)"
return {
	name = "cargo test (当前模块)",
	builder = function()
		-- 向上查找最近的 `mod xxx` 声明
		local module = nil
		for line_num = vim.fn.line("."), 1, -1 do
			local m = vim.fn.getline(line_num):match("mod%s+([%w_]+)")
			if m then
				module = m
				break
			end
		end

		-- fallback：文件顶层没 mod 时，用当前文件名作为模块名
		if not module then
			module = vim.fn.fnamemodify(vim.fn.expand("%"), ":t:r")
		end

		-- 用 `::` 后缀精确匹配该模块及其子模块，避免子串误匹配其他测试
		return {
			cmd = { "cargo", "test", module .. "::" },
			components = { "on_output_quickfix", "default" },
		}
	end,
	condition = {
		filetype = { "rust" },
	},
}
