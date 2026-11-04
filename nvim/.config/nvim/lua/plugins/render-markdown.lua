-- https://github.com/MeanderingProgrammer/render-markdown.nvim
--
-- Markdown 的「原地渲染」（extmark 隐藏标记 + 高亮，不是浏览器预览）。
-- 换掉原来的 markview.nvim：同样的活，只做 markdown，配置稳定、重绘更省。
-- 代价是失去 LaTeX / Typst / HTML / YAML 的渲染（那些仍可交给 mdkite 浏览器预览）。
--
-- 依赖：Neovim >= 0.10、markdown / markdown_inline 解析器（已在 treesitter 的
-- ensure_installed 里）。图标自动探测 mini.icons / nvim-web-devicons，无需配置。
--
-- 它按 FileType 自己 attach，所以别再包一层懒加载（包了只会让首屏渲染变慢）。
--
-- 渲染范围：
--   markdown                         正常渲染
--   codecompanion（chat 浮窗）       强制渲染（buftype=nofile 已由上游 buftype 覆盖处理）
--   ~/.todo-files/、*.todo.md        不渲染 —— 由 ignore() 在 attach 阶段直接拒掉
--   project:// （:Project 概览）      不渲染 —— 那张表是数据，二次排版只是噪音
--
-- 用 ignore() 而不是「attach 后再 disable」：不 attach 就不会动 conceallevel /
-- concealcursor，也不会给 buffer 装一堆 autocmd，todo2 自己那套 conceal 渲染完全不受影响。

-- 这些 buffer 一律不渲染。注意要在 FileType 阶段就能判定（此时 buffer 名已确定）。
local NO_RENDER = {
	"/.todo-files/", -- todo2 的任务文件（~/.todo-files/<项目>/*.todo.md）
}

local function should_ignore(buf)
	local name = vim.api.nvim_buf_get_name(buf)
	if name == "" then
		return false -- 无名 scratch 交给默认规则
	end
	if name:match("%.todo%.md$") then
		return true
	end
	for _, pat in ipairs(NO_RENDER) do
		if name:find(pat, 1, true) then
			return true
		end
	end
	-- :Project 的项目概览（lua/local/project/ui.lua 建的 project:// 名字的 nofile buffer）
	if name:match("^project://") then
		return true
	end
	return false
end

return {
	"MeanderingProgrammer/render-markdown.nvim",
	config = function()
		require("render-markdown").setup({
			-- 上游默认只认 markdown；CodeCompanion 的 chat buffer 走的是注册到
			-- markdown 解析器的 filetype（codecompanion/plugin/codecompanion.lua），
			-- 这里把它加进来才会渲染。
			file_types = { "markdown", "codecompanion" },
			ignore = should_ignore,
		})

		-- <leader>z = 工具分组（zm 是 mdkite 浏览器预览、zt 是 tirenvi 表格视图）
		-- 全局开关不会波及 todo2 / project:// —— 它们压根没 attach。
		vim.keymap.set(
			"n",
			"<leader>zM",
			"<cmd>RenderMarkdown toggle<cr>",
			{ silent = true, desc = "Render-Markdown: 切换原地渲染（全局）" }
		)
		vim.keymap.set(
			"n",
			"<leader>zV",
			"<cmd>RenderMarkdown preview<cr>",
			{ silent = true, desc = "Render-Markdown: 侧边渲染预览" }
		)
	end,
}
