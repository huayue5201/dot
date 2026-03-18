-- https://github.com/jbyuki/one-small-step-for-vimkind

return {
	setup = function(dap)
		-- 辅助函数：检查端口是否可用（简化版）
		local function ensure_osv_running(port)
			if not require("osv").is_running() then
				local ok, result = pcall(function()
					return require("osv").launch({
						port = port,
						host = "127.0.0.1",
						blocking = false,
					})
				end)
				if ok and result then
					print("🚀 osv 启动成功 on port " .. port)
				end
				return result
			end
			return true
		end

		dap.adapters.nlua = function(callback, conf)
			local port = conf.port or 8087 -- 默认改为 8087
			local host = conf.host or "127.0.0.1"

			if conf.start_neovim then
				ensure_osv_running(port)
			end

			callback({
				type = "server",
				host = host,
				port = port,
			})
		end

		dap.configurations.lua = {
			{
				type = "nlua",
				request = "attach",
				name = "🚀 Run this file (auto-start on 8087)",
				start_neovim = true,
				port = 8087, -- 明确指定端口
			},
			{
				type = "nlua",
				request = "attach",
				name = "🔗 Attach to port 8087",
				port = 8087,
			},
			{
				type = "nlua",
				request = "attach",
				name = "🔗 Attach to port 8086 (备用)",
				port = 8086,
			},
		}

		-- 更新快捷键
		vim.keymap.set("n", "<leader>dl", function()
			require("osv").launch({ port = 8087 })
		end, { noremap = true, desc = "启动 osv (端口8087)" })

		vim.keymap.set("n", "<leader>ds", function()
			require("osv").stop()
		end, { noremap = true, desc = "停止 osv" })
	end,
}
