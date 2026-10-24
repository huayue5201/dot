-- https://github.com/michaelb/sniprun
-- SnipRun - 行/选区级别的多语言代码运行器（Rust 写的后端，macOS 需本地编译）

return {
	"michaelb/sniprun",
	-- macOS 没有预编译二进制，install.sh 会自动 fallback 到 cargo build --release，
	-- 产物落在插件目录的 target/release/sniprun。build 的 cwd 是 nvim 的工作目录，
	-- 必须显式 cd 到插件目录，否则找不到 install.sh。
	build = function(plugin)
		local res = vim.system({ "sh", "install.sh" }, { cwd = plugin.dir, text = true }):wait()
		if res.code ~= 0 then
			error("sniprun 构建失败:\n" .. (res.stderr or "") .. (res.stdout or ""))
		end
	end,
	config = function()
		require("sniprun").setup({})

		-- 统一挂到 <leader>rS（运行 / SnipRun），与 <leader>rr/rd（Rust runnables）、
		-- <leader>ru/ro（overseer）、<leader>rt*（toggle）都不冲突。
		vim.keymap.set({ "n", "v" }, "<leader>rSr", "<cmd>SnipRun<CR>", { desc = "SnipRun: 运行当前行/选区" })
		vim.keymap.set("n", "<leader>rSl", "<cmd>SnipLive<CR>", { desc = "SnipRun: 切换 Live 模式（每次改动即运行）" })
		vim.keymap.set("n", "<leader>rSi", "<cmd>SnipInfo<CR>", { desc = "SnipRun: 查看解释器/REPL 状态" })
		vim.keymap.set("n", "<leader>rSc", "<cmd>SnipClose<CR>", { desc = "SnipRun: 关闭结果窗口" })
		vim.keymap.set("n", "<leader>rSx", "<cmd>SnipReset<CR>", { desc = "SnipRun: 重置所有解释器/REPL" })
	end,
}
