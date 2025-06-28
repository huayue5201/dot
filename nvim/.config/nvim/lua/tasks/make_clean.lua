return {
	label = "Make: 清理构建",
	project_type = "make",
	cmd = { "make", "clean" },
	on_complete = function(output)
		vim.notify("✔️ 清理完成", vim.log.levels.INFO)
	end,
}
