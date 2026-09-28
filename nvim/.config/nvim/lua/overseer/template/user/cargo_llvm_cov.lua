-- cargo 生成覆盖率报告（lcov.info）
-- 用法：按 :OverseerRun 选 "cargo llvm-cov (生成覆盖率)"
--       自动从当前 Rust 文件向上定位 Cargo.toml 所在的项目根目录，
--       lcov.info 输出到项目根，配合 crazy-coverage 的 :CoverageToggle 使用
return {
	name = "cargo llvm-cov (生成覆盖率)",
	builder = function()
		-- 从当前文件向上查找 Cargo.toml，定位项目根目录
		-- （不依赖 nvim 的 cwd，避免在非项目目录里运行失败）
		local buf = vim.fn.expand("%:p")
		local root = ""
		if buf ~= "" then
			local cargo = vim.fn.findfile("Cargo.toml", vim.fn.fnamemodify(buf, ":p:h") .. ";")
			if cargo ~= "" then
				root = vim.fn.fnamemodify(cargo, ":p:h")
			end
		end
		if root == "" then
			root = vim.fn.getcwd()
		end

		return {
			cmd = { "cargo", "llvm-cov", "--lcov", "--output-path", "lcov.info" },
			cwd = root,
			components = { "on_output_quickfix", "default" },
		}
	end,
	condition = {
		filetype = { "rust" },
	},
}
