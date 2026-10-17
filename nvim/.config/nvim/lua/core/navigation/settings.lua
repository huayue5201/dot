-- 缓冲区特殊设置（数据）
-- 格式：filetype/buftype -> { setup = function, size = { width/height } }
-- size 声明窗口的期望尺寸，布局变化后由 core.navigation.winfix_guard 强制维持。
return {
	["dap-repl"] = {
		setup = function()
			vim.opt_local.confirm = false
			vim.opt.buflisted = false
		end,
	},
	["neotest-output"] = {
		setup = function()
			vim.opt_local.winfixbuf = true
			vim.opt.buflisted = false
		end,
	},
	["sqmeow-drawer"] = {
		size = function()
			local ok, width = pcall(function()
				return require("sqmeow.config").get().ui.drawer.width
			end)
			return { width = ok and width or 42 }
		end,
	},
	["sqmeow-result"] = {
		size = function()
			local ok, height = pcall(function()
				return require("sqmeow.config").get().ui.result.height
			end)
			return { height = ok and height or 16 }
		end,
	},
}
