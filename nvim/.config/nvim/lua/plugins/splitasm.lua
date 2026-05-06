-- https://github.com/NickTsaizer/splitasm.nvim

return {
	"NickTsaizer/splitasm.nvim",
	cmd = {
		"SplitAsm",
		"SplitAsmOpen",
		"SplitAsmSetup",
		"SplitAsmConfig",
		"SplitAsmToggleSync",
	},
	event = "VeryLazy",
	config = function()
		require("splitasm").setup({
			compiler_cmd = "cargo build", -- debug 模式，自带调试符号
			executable_path = "./target/debug/data_pulse", -- 改为你的项目名
			auto_sync = true,
			clean_asm = true, -- 保持原始输出，方便调试
			source_row_colors = true,
		})
		vim.keymap.set("n", "<Leader>zs", "<cmd>SplitAsmOpen<cr>", { desc = "splitasm: 查看汇编" })
	end,
}
