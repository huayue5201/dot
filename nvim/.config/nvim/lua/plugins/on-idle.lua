-- https://codeberg.org/dannyfritz/on-idle.nvim
-- 长时间空闲（终端窗口失焦）后自动挂起 LSP 语言服务器以释放内存，重新聚焦时恢复。
-- 只做 vim.lsp.enable(name, false/true)：不改 option、不建键位、不碰其他插件。
--
-- 依赖 lua-state-machine：on-idle 在模块顶层会用 `vim.pack.add` 自行安装它。
-- 这里改由 zpack 统一声明并管理该依赖，并在 config 里临时短路 vim.pack.add，
-- 避免插件自管依赖造成重复安装 / 锁文件抖动。
return {
	"https://codeberg.org/dannyfritz/on-idle.nvim",
	-- 启动后再加载，避免影响启动路径
	event = "VeryLazy",
	dependencies = {
		-- 与 on-idle 内部 pin 的 commit 保持一致
		{ "kyleconroy/lua-state-machine", commit = "96fc10ee123479cf2e5fb8ffe9cdde2fd6df0877" },
	},
	opts = {
		-- 失焦后多久挂起 LSP（秒），默认 1 小时
		timeout_seconds = 60 * 60,
		-- 重新聚焦后等待多久再恢复（秒）
		grace_period_seconds = 5,
	},
	config = function(_, opts)
		local add = vim.pack and vim.pack.add
		if add then
			vim.pack.add = function() end
		end
		local ok, mod = pcall(require, "on-idle")
		if add then
			vim.pack.add = add
		end
		if not ok then
			vim.notify("on-idle 加载失败: " .. tostring(mod), vim.log.levels.ERROR)
			return
		end
		mod.setup(opts)
	end,
}
