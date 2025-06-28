return {
	-- 任务显示名称
	label = "Make: 构建项目",
	-- 匹配的项目类型
	project_type = "make",
	-- 要执行的命令
	cmd = { "make" },
	-- 自定义输出处理器（可选）
	on_output = function(lines)
		-- 这里可以添加自定义输出处理逻辑
		-- 例如高亮特定关键词或提取关键信息
	end,
	-- 任务完成时的回调
	on_complete = function(output)
		vim.notify("✔️ make 构建成功", vim.log.levels.INFO)
		-- 这里可以添加构建成功后的操作
		-- 例如：自动加载构建结果、运行测试等
	end,
	-- 任务失败时的回调
	on_fail = function(output)
		vim.notify("❌ make 构建失败，请查看 Quickfix", vim.log.levels.ERROR)
		-- 这里可以添加构建失败后的操作
		-- 例如：自动定位到第一个错误
	end,
}
