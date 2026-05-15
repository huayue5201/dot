-- https://github.com/obsidian-nvim/obsidian.nvim

return {
	"obsidian-nvim/obsidian.nvim",
	event = "VeryLazy",
	version = "*", -- use latest release, remove to use latest commit
	---@module 'obsidian'
	---@type obsidian.config
	config = function()
		require("obsidian").setup({
			legacy_commands = false, -- this will be removed in 4.0.0
			workspaces = {
				{
					name = "buf-parent",
					path = function()
						return assert(vim.fs.dirname(vim.api.nvim_buf_get_name(0)))
					end,
				},
				{
					name = "work",
					path = "~/notes",
				},
			},
		})
		-- 以 <Leader>ob 为前缀的 Obsidian 映射
		local map = vim.keymap.set
		local opts = { noremap = true, silent = true }

		local mappings = {
			-- 核心功能
			{ "n", "<Leader>obf", "<cmd>Obsidian quick_switch<cr>", "快速切换笔记" },
			{ "n", "<Leader>obs", "<cmd>Obsidian search<cr>", "搜索笔记" },
			{ "n", "<Leader>obn", "<cmd>Obsidian new<cr>", "新建笔记" },
			{ "n", "<Leader>obd", "<cmd>Obsidian today<cr>", "今日日记" },
			{ "n", "<Leader>oby", "<cmd>Obsidian yesterday<cr>", "昨日日记" },
			{ "n", "<Leader>obt", "<cmd>Obsidian tomorrow<cr>", "明日日记" },
			{ "n", "<Leader>obw", "<cmd>Obsidian workspace<cr>", "切换工作区" },
			-- 当前笔记操作
			{ "n", "<Leader>obb", "<cmd>Obsidian backlinks<cr>", "查看反向链接" },
			{ "n", "<Leader>obr", "<cmd>Obsidian rename<cr>", "重命名笔记" },
			{ "n", "<Leader>obc", "<cmd>Obsidian toggle_checkbox<cr>", "切换复选框" },
			{ "n", "<Leader>obp", "<cmd>Obsidian paste_img<cr>", "粘贴图片" },
			{ "n", "<Leader>obm", "<cmd>Obsidian template<cr>", "插入模板" },
			{ "n", "<Leader>obo", "<cmd>Obsidian open<cr>", "在 Obsidian 应用中打开" },
			-- 可视化模式
			{ "v", "<Leader>obl", "<cmd>Obsidian link<cr>", "链接选中文字到笔记" },
			{ "v", "<Leader>obL", "<cmd>Obsidian link_new<cr>", "从选中文字新建笔记并链接" },
			{ "v", "<Leader>obe", "<cmd>Obsidian extract_note<cr>", "提取选中内容为新笔记" },
			-- 链接导航
			{ "n", "[o", "<cmd>Obsidian follow_link<cr>", "上一个链接" },
			{ "n", "]o", "<cmd>Obsidian follow_link<cr>", "下一个链接" },
		}

		for _, mapping in ipairs(mappings) do
			local mode, lhs, rhs, desc = unpack(mapping)
			map(mode, lhs, rhs, vim.tbl_extend("force", opts, { desc = desc }))
		end

		-- 智能回车
		map("n", "<CR>", function()
			if vim.bo.filetype == "markdown" then
				vim.cmd("Obsidian follow_link")
			else
				vim.cmd("normal! <CR>")
			end
		end, vim.tbl_extend("force", opts, { desc = "跟随 Obsidian 链接" }))
	end,
}
