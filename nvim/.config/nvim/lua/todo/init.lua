-- lua/todo/init.lua
local core = require("todo.core")
local render = require("todo.render")
local link = require("todo.link")
local ui = require("todo.ui")

local M = {}

---------------------------------------------------------------------
-- 插件初始化
---------------------------------------------------------------------
function M.setup()
	-------------------------------------------------------------------
	-- 高亮组（删除线、灰色）
	-------------------------------------------------------------------
	vim.cmd([[
    highlight TodoCompleted guifg=#888888 gui=italic
    highlight TodoStrikethrough gui=strikethrough cterm=strikethrough
  ]])

	-------------------------------------------------------------------
	-- 全局按键映射（双向链接）
	-------------------------------------------------------------------
	vim.keymap.set("n", "<leader>tda", link.create_link, { desc = "创建代码→TODO 链接" })
	vim.keymap.set("n", "<leader>tdj", link.jump_to_todo, { desc = "跳到 TODO 项" })
	vim.keymap.set("n", "<leader>tdc", link.jump_to_code, { desc = "跳回代码" })

	-------------------------------------------------------------------
	-- 双链标记管理（新增精简版功能）
	-------------------------------------------------------------------
	local manager = require("todo.manager")

	-- qf: QuickFix 管理所有标记
	vim.keymap.set("n", "<leader>tdq", manager.show_project_links_qf, { desc = "显示所有双链标记 (QuickFix)" })

	-- fx: LocList 管理当前缓冲区标记
	vim.keymap.set(
		"n",
		"<leader>tdl",
		manager.show_buffer_links_loclist,
		{ desc = "显示当前缓冲区双链标记 (LocList)" }
	)

	-- 修复孤立的标记
	vim.keymap.set(
		"n",
		"<leader>tdr",
		manager.fix_orphan_links_in_buffer,
		{ desc = "修复当前缓冲区孤立的标记" }
	)

	-- 显示统计信息
	vim.keymap.set("n", "<leader>tdw", manager.show_stats, { desc = "显示双链标记统计" })

	-------------------------------------------------------------------
	-- 悬浮预览（按 K）
	-------------------------------------------------------------------
	vim.keymap.set("n", "<leader>tk", function()
		local line = vim.fn.getline(".")
		if line:match("TODO:ref:(%w+)") then
			link.preview_todo()
		elseif line:match("{#(%w+)}") then
			link.preview_code()
		else
			vim.lsp.buf.hover()
		end
	end, { desc = "预览 TODO 或代码" })

	-------------------------------------------------------------------
	-- TODO 文件管理 - 增强版：支持多种打开方式
	-------------------------------------------------------------------
	-- 选择并浮窗打开
	vim.keymap.set("n", "<leader>tdf", function()
		ui.select_and_open("current", "floating")
	end, { desc = "TODO: 浮窗打开列表" })

	-- 选择并下分屏打开
	vim.keymap.set("n", "<leader>tds", function()
		ui.select_and_open("current", "split")
	end, { desc = "TODO: 下分屏打开列表" })

	-- 在当前窗口打开（保持原有功能）
	vim.keymap.set("n", "<leader>tde", function()
		ui.select_todo_file("current", function(choice)
			if choice then
				ui.open_todo_file(choice.path, "current")
			end
		end)
	end, { desc = "TODO: 当前窗口打开列表" })

	-- 创建 TODO 文件
	vim.keymap.set("n", "<leader>tdn", function()
		local path = ui.create_todo_file()
		if path then
			-- 创建后自动用下分屏打开
			vim.defer_fn(function()
				ui.open_todo_file_split(path)
			end, 100)
		end
	end, { desc = "TODO: 创建文件" })

	-- 删除 TODO 文件
	vim.keymap.set("n", "<leader>tdd", function()
		ui.select_todo_file("current", function(choice)
			if choice then
				ui.delete_todo_file(choice.path)
			end
		end)
	end, { desc = "TODO: 删除文件" })

	-- 快速打开最近的文件（新增功能）
	vim.keymap.set("n", "<leader>tdh", function()
		-- 这里可以扩展为打开最近编辑的 TODO 文件
		vim.notify("TODO: 最近文件功能待实现", vim.log.levels.INFO)
	end, { desc = "TODO: 打开最近文件" })

	-------------------------------------------------------------------
	-- 自动同步：代码文件
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.lua", "*.rs", "*.go", "*.ts", "*.js", "*.py", "*.c", "*.cpp" },
		callback = function()
			vim.defer_fn(function()
				require("todo.link").sync_code_links()
			end, 0)
		end,
	})

	-------------------------------------------------------------------
	-- 自动同步：TODO 文件
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.todo.md", "*.todo", "todo.txt" },
		callback = function()
			vim.schedule(function()
				require("todo.link").sync_todo_links()
			end)
		end,
	})

	-- lazy load 标记状态渲染
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "lua", "rust", "go", "python", "javascript", "typescript", "c", "cpp" },
		callback = function(args)
			-- 延迟加载虚拟字符渲染
			vim.schedule(function()
				require("todo.link").render_code_status(args.buf)
			end)
		end,
	})

	-------------------------------------------------------------------
	-- 自动设置 TODO 文件窗口特性
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("FileType", {
		pattern = "markdown",
		callback = function(args)
			local bufname = vim.api.nvim_buf_get_name(args.buf)
			if bufname:match("%.todo%.md$") then
				-- 如果是 TODO 文件，应用 conceal 设置
				vim.schedule(function()
					require("todo.ui").refresh(args.buf)
				end)
			end
		end,
	})
end

---------------------------------------------------------------------
-- 对外暴露 API
---------------------------------------------------------------------
M.core = core
M.render = render
M.link = link
M.ui = ui
M.manager = require("todo.manager")

-- 提供便捷的打开方式函数
function M.open_split_todo()
	ui.select_and_open("current", "split")
end

function M.open_floating_todo()
	ui.select_and_open("current", "floating")
end

function M.open_current_todo()
	ui.select_and_open("current", "current")
end

return M
