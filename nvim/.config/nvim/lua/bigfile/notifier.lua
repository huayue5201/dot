local M = {}

-- 生成手动操作通知
function M.generate_manual_notification(buf, action, rule_name)
	local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t")

	if action == "force_reset" then
		return string.format("✅ %s: 手动恢复所有小文件配置", filename)
	elseif action == "force_apply" then
		return string.format("📦 %s: 手动应用所有大文件配置", filename)
	elseif action == "status" then
		return string.format("📊 %s: BigFile 状态查询", filename)
	end
end

return M
