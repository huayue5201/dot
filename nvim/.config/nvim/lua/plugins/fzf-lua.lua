-- https://github.com/ibhagwan/fzf-lua

return {
	"ibhagwan/fzf-lua",
	event = "VeryLazy",
	-- optional for icon support
	dependencies = { "nvim-tree/nvim-web-devicons" },
	-- or if using mini.icons/mini.nvim
	-- dependencies = { "nvim-mini/mini.icons" },
	config = function()
		require("fzf-lua").setup({
			keymap = {
				fzf = {
					true,
					-- Use <c-q> to select all items and add them to the quickfix list
					["ctrl-q"] = "select-all+accept",
				},
			},
		})
		vim.keymap.set("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "fzf: files" })
		vim.keymap.set("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "fzf: buffer" })
		vim.keymap.set("n", "<leader>fB", "<cmd>FzfLua tabs<cr>", { desc = "fzf: tab" })
		vim.keymap.set("n", "<leader>fo", "<cmd>FzfLua oldfiles<cr>", { desc = "fzf: oldfiles" })
		vim.keymap.set("n", "<leader>fc", "<cmd>FzfLua commands<cr>", { desc = "fzf: cmd" })
		vim.keymap.set("n", "<leader>fR", function()
			require("fzf-lua").grep({ resume = true })
		end, { desc = "fzf: grep" })
		vim.keymap.set("n", "<leader>fr", "<cmd>FzfLua grep_curbuf<cr>", { desc = "fzf: grep buffer" })
		vim.keymap.set("n", "<leader>ft", "<cmd>FzfLua btags<cr>", { desc = "fzf: btags" })
		vim.keymap.set("n", "<leader>fT", "<cmd>FzfLua tags<cr>", { desc = "fzf: workspaces tags" })
		-- 引用与定义相关
		vim.keymap.set("n", "<leader>flr", "<cmd>FzfLua lsp_references<cr>", { desc = "查找引用" })
		vim.keymap.set("n", "<leader>fld", "<cmd>FzfLua lsp_definitions<cr>", { desc = "跳转到定义" })
		vim.keymap.set("n", "<leader>flD", "<cmd>FzfLua lsp_declarations<cr>", { desc = "跳转到声明" })
		vim.keymap.set("n", "<leader>flt", "<cmd>FzfLua lsp_typedefs<cr>", { desc = "跳转到类型定义" })
		vim.keymap.set("n", "<leader>fli", "<cmd>FzfLua lsp_implementations<cr>", { desc = "查找实现" })

		-- 符号搜索（你已有一部分）
		vim.keymap.set("n", "<leader>fls", "<cmd>FzfLua lsp_document_symbols<cr>", { desc = "文档符号" })
		vim.keymap.set("n", "<leader>flw", "<cmd>FzfLua lsp_workspace_symbols<cr>", { desc = "工作区符号" })
		vim.keymap.set(
			"n",
			"<leader>flS",
			"<cmd>FzfLua lsp_live_workspace_symbols<cr>",
			{ desc = "工作区符号(实时)" }
		)
		vim.keymap.set("n", "<leader>flc", "<cmd>FzfLua lsp_incoming_calls<cr>", { desc = "传入调用" })
		vim.keymap.set("n", "<leader>flC", "<cmd>FzfLua lsp_outgoing_calls<cr>", { desc = "传出调用" })
		vim.keymap.set("n", "<leader>flts", "<cmd>FzfLua lsp_type_sub<cr>", { desc = "子类型" })
		vim.keymap.set("n", "<leader>fltS", "<cmd>FzfLua lsp_type_super<cr>", { desc = "父类型" })
		vim.keymap.set("n", "<leader>fla", "<cmd>FzfLua lsp_code_actions<cr>", { desc = "代码操作" })
		vim.keymap.set("n", "<leader>flf", "<cmd>FzfLua lsp_finder<cr>", { desc = "联合查找器" })
		-- 诊断相关
		vim.keymap.set("n", "<leader>fldi", "<cmd>FzfLua diagnostics_document<cr>", { desc = "文档诊断" })
		vim.keymap.set("n", "<leader>fldI", "<cmd>FzfLua diagnostics_workspace<cr>", { desc = "工作区诊断" })
		vim.keymap.set("n", "<leader>fdc", "<cmd>FzfLua  dap_commands<cr>", { desc = "fzf: dap cmd" })
		vim.keymap.set("n", "<leader>fdb", "<cmd>FzfLua  dap_breakpoints<cr>", { desc = "fzf: dap breakpoints" })
		vim.keymap.set("n", "<leader>fdo", "<cmd>FzfLua  dap_configurations<cr>", { desc = "fzf: dap config" })
		vim.keymap.set(
			"n",
			"<leader>fdv",
			"<cmd>FzfLua  dap_variables<cr>",
			{ desc = "fzf: dap active session variables" }
		)
		-- Git 文件与状态相关
		vim.keymap.set("n", "<leader>fhf", "<cmd>FzfLua git_files<cr>", { desc = "Git文件列表" })
		vim.keymap.set("n", "<leader>fhs", "<cmd>FzfLua git_status<cr>", { desc = "Git状态" })
		vim.keymap.set("n", "<leader>fhd", "<cmd>FzfLua git_diff<cr>", { desc = "Git差异对比" })
		vim.keymap.set("n", "<leader>fhh", "<cmd>FzfLua git_hunks<cr>", { desc = "Git代码块差异" })

		-- Git 提交历史相关
		vim.keymap.set("n", "<leader>fhc", "<cmd>FzfLua git_commits<cr>", { desc = "Git提交记录(项目)" })
		vim.keymap.set("n", "<leader>fhC", "<cmd>FzfLua git_bcommits<cr>", { desc = "Git提交记录(当前文件)" })
		vim.keymap.set("n", "<leader>fhb", "<cmd>FzfLua git_blame<cr>", { desc = "Git代码追溯" })

		-- Git 分支与标签管理
		vim.keymap.set("n", "<leader>fhr", "<cmd>FzfLua git_branches<cr>", { desc = "Git分支列表" })
		vim.keymap.set("n", "<leader>fhw", "<cmd>FzfLua git_worktrees<cr>", { desc = "Git工作树" })
		vim.keymap.set("n", "<leader>fht", "<cmd>FzfLua git_tags<cr>", { desc = "Git标签" })
		vim.keymap.set("n", "<leader>fhx", "<cmd>FzfLua git_stash<cr>", { desc = "Git储藏栈" })
		vim.keymap.set(
			"n",
			"<leader>fdf",
			"<cmd>FzfLua  dap_frames<cr>",
			{ desc = "fzf: dap active session jump to frame" }
		)
		vim.keymap.set("n", "<leader>fu", "<cmd>FzfLua undotree<cr>", { desc = "fzf: undotree" })
		vim.keymap.set("n", "<leader>fk", "<cmd>FzfLua keymaps<cr>", { desc = "fzf: keymaps" })
	end,
}
