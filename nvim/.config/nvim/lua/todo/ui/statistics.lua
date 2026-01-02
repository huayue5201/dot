-- lua/todo/ui/statistics.lua
local M = {}

function M.format_summary(stat)
	if stat.total_items == 0 then
		return "暂无任务"
	end

	local ratio = stat.completed_items / stat.total_items
	local filled = math.floor(ratio * 20)
	local bar = string.rep("▰", filled) .. string.rep("▱", 20 - filled)

	if stat.total_tasks == stat.total_items then
		return string.format(
			"%s %d%%｜完成: %d/%d",
			bar,
			math.floor(ratio * 100),
			stat.completed_items,
			stat.total_items
		)
	else
		return string.format(
			"%s %d%%｜主任务: %d/%d｜总计: %d/%d",
			bar,
			math.floor(ratio * 100),
			stat.done,
			stat.total_tasks,
			stat.completed_items,
			stat.total_items
		)
	end
end

return M
