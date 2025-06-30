return {
	id = "dependency_task",
	label = "测试依赖任务",
	cmd = "echo '依赖任务执行中...'; sleep 1; echo '依赖任务完成'; exit 0",
	on_complete = function(output)
		vim.notify("依赖任务完成: " .. output[1], vim.log.levels.INFO)
	end,
}
