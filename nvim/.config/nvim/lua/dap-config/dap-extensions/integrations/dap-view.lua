local M = {}

function M.setup()
	local ok, dap_view = pcall(require, "dap-view")
	if not ok then
		vim.notify("dap-view not installed", vim.log.levels.WARN)
		return
	end

	local manager = require("dap-config.dap-extensions.manager")
	local registry = require("dap-config.dap-extensions.registry")

	local dap = require("dap")

	local original_on_stopped = manager.on_stopped

	manager.on_stopped = function(session, event)
		original_on_stopped(session, event)

		-- 强制刷新 dap-view UI
		vim.schedule(function()
			pcall(function()
				dap_view.open()
				dap_view.refresh()
			end)
		end)
	end

	-- ============================================================
	-- 🔥 关键：把 registry 同步到 nvim-dap breakpoints
	-- ============================================================
	local function sync_to_nvim_dap()
		local dap_bps = {}

		for _, bp in pairs(registry.bps) do
			if bp.status == "verified" and bp.config.bufnr and bp.config.line then
				local buf = bp.config.bufnr
				dap_bps[buf] = dap_bps[buf] or {}

				dap_bps[buf][bp.config.line] = {
					condition = bp.config.condition,
					hitCondition = bp.config.hitCondition,
					logMessage = bp.config.logMessage,
				}
			end
		end

		dap.breakpoints = dap_bps
	end

	-- 每次 event 或 sync 后更新
	local event = require("dap-config.dap-extensions.event")

	event.on("bp_hit", sync_to_nvim_dap)
	event.on("breakpoint_changed", sync_to_nvim_dap)

	vim.notify("dap-view integration enabled", vim.log.levels.INFO)
end

return M
