-- https://github.com/kibi2/tirenvi.nvim
-- Markdown / CSV / TSV 表格的结构化编辑：`:Tir` 在「原始文本」和「对齐后的表格视图」
-- 之间切换，保存时再无损转回原格式。
--
-- 后端是三个 Python 包（tir-csv / tir-gfm-lite / tir-embedded），装在独立 venv 里，
-- 不污染系统 python：
--   ~/.local/share/tirenvi/venv/bin/{tir-csv,tir-gfm-lite,tir-embedded}
-- 升级：
--   uv pip install --python ~/.local/share/tirenvi/venv/bin/python --upgrade \
--     git+https://github.com/kibi2/tir-csv \
--     git+https://github.com/kibi2/tir-gfm-lite \
--     git+https://github.com/kibi2/tir-embedded
-- 装不上（没有 venv）时插件本身仍可用，只是解析器检查会报错，表格功能不可用。

local venv_bin = vim.fs.joinpath(vim.fn.stdpath("data"), "tirenvi", "venv", "bin")
if vim.uv.fs_stat(venv_bin) then
	local path = vim.env.PATH or ""
	if not path:find(venv_bin, 1, true) then
		vim.env.PATH = venv_bin .. ":" .. path
	end
end

return {
	"kibi2/tirenvi.nvim",
	config = function()
		require("tirenvi").setup({
			parser_map = {
				-- CodeCompanion 的聊天 / 输入缓冲区内容就是 GFM，让 `:Tir` 在那边也能用。
				-- 这两个 filetype 归上游时没有解析器（parser_map 只按 filetype 精确匹配），
				-- 所以不影响默认行为；不加这两行 CodeCompanion 里 :Tir 会报“无解析器”。
				codecompanion = {
					executable = "tir-gfm-lite",
					allow_plain = true,
					required_version = "0.1.6",
				},
				["codecompanion_input"] = {
					executable = "tir-gfm-lite",
					allow_plain = true,
					required_version = "0.1.6",
				},
			},
		})

		-- 结构移动（<C-h/j/k/l> 切上一个/下一个单元格、块首/块尾）。
		-- 插件**不自带**映射（README 里那段是示例），而这几个键在 n/x 已被 smart-splits
		-- 占据，所以只在表格视图（b:tirenvi.tirbuf 为真，即 :Tir 后的对齐视图）里做
		-- buffer-local 覆盖，退出表格视图立即撤掉，窗口间跳转不受影响。
		local function sync_tir_motions(buf)
			local st = vim.b[buf].tirenvi
			local on = type(st) == "table" and st.tirbuf == true
			if (vim.b[buf]._tir_motions or 0) == (on and 1 or 0) then
				return
			end
			vim.b[buf]._tir_motions = on and 1 or 0

			local motion = require("tirenvi").motion
			local maps = {
				["<C-h>"] = { motion.cell_prev, "TirEnvi: previous cell" },
				["<C-l>"] = { motion.cell_next, "TirEnvi: next cell" },
				["<C-k>"] = { motion.block_top, "TirEnvi: block start" },
				["<C-j>"] = { motion.block_bottom, "TirEnvi: block end" },
			}
			for lhs, m in pairs(maps) do
				if on then
					vim.keymap.set({ "n", "o", "x" }, lhs, m[1], { expr = true, buffer = buf, desc = m[2] })
				else
					pcall(vim.keymap.del, { "n", "o", "x" }, lhs, { buffer = buf })
				end
			end
		end

		-- :Tir 是自己敲的（不进 <leader>zt）时也要跟上，靠这些事件打补丁。
		-- 非表格 buffer 在 sync 里第一行就返回，开销可忽。
		vim.api.nvim_create_autocmd({ "BufEnter", "BufWinEnter", "TextChanged", "TextChangedI", "ModeChanged" }, {
			group = vim.api.nvim_create_augroup("user_tirenvi_motions", { clear = true }),
			callback = function(args)
				sync_tir_motions(args.buf)
			end,
		})

		-- 表格视图：原始文本 ⇄ 对齐后的 tir-buf（保存时无损转回原格式）
		-- `<leader>z` 是工具分组，取 zt（z 下已占用：zm zp zx zX zz）。
		-- 缓冲区没有解析器时 :Tir 会直接抛错，这里先挡一下换成友好提示。
		vim.keymap.set("n", "<leader>zt", function()
			local ok, state = pcall(require, "tirenvi.io.buf_state")
			local parser = ok and state.get(vim.api.nvim_get_current_buf(), state.IKEY.PARSER)
			if not parser then
				vim.notify(
					"Current buffer does not support table view (requires csv/tsv/markdown/codecompanion)",
					vim.log.levels.WARN
				)
				return
			end
			vim.cmd("Tir toggle")
			sync_tir_motions(vim.api.nvim_get_current_buf())
		end, { desc = "Toggle table view (tirenvi)" })
	end,
}
