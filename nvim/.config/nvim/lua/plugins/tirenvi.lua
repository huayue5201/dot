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

		-- 表格视图：原始文本 ⇄ 对齐后的 tir-buf（保存时无损转回原格式）
		-- `<leader>z` 是工具分组，取 zt（z 下已占用：zm zp zx zX zz）。
		-- 缓冲区没有解析器时 :Tir 会直接抛错，这里先挡一下换成友好提示。
		vim.keymap.set("n", "<leader>zt", function()
			local ok, state = pcall(require, "tirenvi.io.buf_state")
			local parser = ok and state.get(vim.api.nvim_get_current_buf(), state.IKEY.PARSER)
			if not parser then
				vim.notify("当前缓冲区不支持表格视图（需 csv/tsv/markdown/codecompanion）", vim.log.levels.WARN)
				return
			end
			vim.cmd("Tir toggle")
		end, { desc = "表格视图切换 (tirenvi)" })
	end,
}
