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
			error("sniprun build failed:\n" .. (res.stderr or "") .. (res.stdout or ""))
		end
	end,
	config = function()
		require("sniprun").setup({})

		-- 统一挂到 <leader>rS（运行 / SnipRun），与 <leader>rr/rd（Rust runnables）、
		-- <leader>ru/ro（overseer）、<leader>rt*（toggle）都不冲突。
		vim.keymap.set(
			{ "n", "v" },
			"<leader>rSr",
			"<cmd>SnipRun<CR>",
			{ desc = "SnipRun: run current line/selection" }
		)
		vim.keymap.set(
			"n",
			"<leader>rSl",
			"<cmd>SnipLive<CR>",
			{ desc = "SnipRun: toggle Live mode (run on every change)" }
		)
		vim.keymap.set("n", "<leader>rSi", "<cmd>SnipInfo<CR>", { desc = "SnipRun: show interpreter/REPL status" })
		vim.keymap.set("n", "<leader>rSc", "<cmd>SnipClose<CR>", { desc = "SnipRun: close result window" })
		vim.keymap.set("n", "<leader>rSx", "<cmd>SnipReset<CR>", { desc = "SnipRun: reset all interpreters/REPL" })
	end,
}
