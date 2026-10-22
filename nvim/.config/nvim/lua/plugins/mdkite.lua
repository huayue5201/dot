-- https://github.com/selimacerbas/mdkite.nvim
-- NOTE: mermaid-rs-renderer（可选）：cargo install mermaid-rs-renderer，使美人鱼渲染速度提高约400倍。在配置中设置mermaid_renderer = "rust"以启用。

return {
	"selimacerbas/mdkite.nvim",
	-- 如果 kitehost.nvim 的 checkout 放在别的目录名下，这份 spec 必须显式写
	-- name = "kitehost.nvim"，否则 vim.pack 会在旁边再装一份上游副本
	dependencies = { "selimacerbas/kitehost.nvim" },
	-- kitehost.nvim v2.0.0 or newer, the first release with its Host check
	-- 注意：key 级 ft 字段不生效（加载器只读 lhs/rhs/mode/desc 等），此键全局可用
	keys = {
		{ "<leader>zm", "<cmd>MdKite toggle<cr>", desc = "Markdown preview" },
	},
	config = function()
		require("mdkite").setup({
			-- all optional; sane defaults shown
			instance_mode = "takeover", -- "takeover" (one tab) or "multi" (tab per instance)
			mermaid_renderer = "rust",
			port = 0, -- 0 = auto (8421 for takeover, OS-assigned for multi)
			open_browser = true,
			default_theme = "dark", -- "dark" or "light"; initial preview theme
			debounce_ms = 300,
		})
	end,
}
