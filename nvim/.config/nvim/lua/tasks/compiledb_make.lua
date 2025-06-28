return {
	label = "compiledb make (动态)",
	project_type = "make",
	cmd = function()
		-- 动态决定是否添加额外参数
		local extra_args = {}
		if vim.fn.filereadable("Makefile") == 1 then
			table.insert(extra_args, "-f")
			table.insert(extra_args, "Makefile")
		end

		return { "compiledb", "make", unpack(extra_args) }
	end,
	on_complete = function(output)
		vim.notify("✔️ compiledb make 执行成功", vim.log.levels.INFO)
	end,
	on_fail = function(output)
		vim.notify("❌ compiledb make 执行失败", vim.log.levels.ERROR)
	end,
}
