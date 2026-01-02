-- lua/todo/init.lua
local M = {}

-- 默认配置
local default_config = {
	link = {
		jump = {
			keep_todo_split_when_jump = true, -- 分屏TODO跳转时是否保持分屏窗口
			default_todo_window_mode = "float", -- 默认打开TODO的窗口模式: "float" | "split" | "vsplit"
			reuse_existing_windows = true, -- 是否复用已存在的窗口
		},
		preview = {
			enabled = true, -- 是否启用预览功能
			border = "rounded", -- 预览窗口边框样式
		},
		render = {
			show_status_in_code = true, -- 在代码中显示TODO状态
		},
	},
}

---------------------------------------------------------------------
-- 插件初始化
---------------------------------------------------------------------
function M.setup(user_config)
	-- 合并用户配置和默认配置
	local config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config or {})

	-------------------------------------------------------------------
	-- 加载核心模块（延迟加载）
	-------------------------------------------------------------------
	M.core = require("todo.core")
	M.render = require("todo.render")
	M.link = require("todo.link")
	M.ui = require("todo.ui")
	M.manager = require("todo.manager")

	-------------------------------------------------------------------
	-- 应用配置到 link 模块
	-------------------------------------------------------------------
	if config.link and M.link.setup then
		M.link.setup(config.link)
	end

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
	vim.keymap.set("n", "<leader>tda", M.link.create_link, { desc = "创建代码→TODO 链接" })
	-- 动态跳转（如果存在该函数）
	vim.keymap.set("n", "gj", M.link.jump_dynamic, { desc = "动态跳转 TODO <-> 代码" })
	-- vim.keymap.set("n", "<leader>tdj", M.link.jump_to_todo, { desc = "跳到 TODO 项" })
	-- vim.keymap.set("n", "<leader>tdc", M.link.jump_to_code, { desc = "跳回代码" })

	-------------------------------------------------------------------
	-- 双链标记管理
	-------------------------------------------------------------------
	vim.keymap.set(
		"n",
		"<leader>tdq",
		M.manager.show_project_links_qf,
		{ desc = "显示所有双链标记 (QuickFix)" }
	)
	vim.keymap.set(
		"n",
		"<leader>tdl",
		M.manager.show_buffer_links_loclist,
		{ desc = "显示当前缓冲区双链标记 (LocList)" }
	)
	vim.keymap.set(
		"n",
		"<leader>tdr",
		M.manager.fix_orphan_links_in_buffer,
		{ desc = "修复当前缓冲区孤立的标记" }
	)
	vim.keymap.set("n", "<leader>tdw", M.manager.show_stats, { desc = "显示双链标记统计" })

	-------------------------------------------------------------------
	-- 悬浮预览（按 K）
	-------------------------------------------------------------------
	vim.keymap.set("n", "<leader>tk", function()
		local line = vim.fn.getline(".")
		if line:match("TODO:ref:(%w+)") then
			M.link.preview_todo()
		elseif line:match("{#(%w+)}") then
			M.link.preview_code()
		else
			vim.lsp.buf.hover()
		end
	end, { desc = "预览 TODO 或代码" })

	-------------------------------------------------------------------
	-- TODO 文件管理 - 多种窗口模式
	-------------------------------------------------------------------
	-- 浮窗打开
	vim.keymap.set("n", "<leader>tdo", function()
		M.ui.select_todo_file("current", function(choice)
			if choice then
				M.ui.open_todo_file(choice.path, "float", 1, { enter_insert = false }) -- 改为1或nil
			end
		end)
	end, { desc = "TODO: 浮窗打开" })

	-- 水平分割打开
	vim.keymap.set("n", "<leader>tds", function()
		M.ui.select_todo_file("current", function(choice)
			if choice then
				M.ui.open_todo_file(choice.path, "split", 1, {
					enter_insert = false,
					split_direction = "horizontal",
				})
			end
		end)
	end, { desc = "TODO: 水平分割打开" })

	-- 垂直分割打开
	vim.keymap.set("n", "<leader>tdv", function()
		M.ui.select_todo_file("current", function(choice)
			if choice then
				M.ui.open_todo_file(choice.path, "split", 1, {
					enter_insert = false,
					split_direction = "vertical",
				})
			end
		end)
	end, { desc = "TODO: 垂直分割打开" })

	-- 编辑模式打开
	vim.keymap.set("n", "<leader>tde", function()
		M.ui.select_todo_file("current", function(choice)
			if choice then
				M.ui.open_todo_file(choice.path, "edit", 1, { enter_insert = false })
			end
		end)
	end, { desc = "TODO: 编辑模式打开" })

	-- 创建 TODO 文件
	vim.keymap.set("n", "<leader>tdn", function()
		M.ui.create_todo_file()
	end, { desc = "TODO: 创建文件" })

	-- 删除 TODO 文件
	vim.keymap.set("n", "<leader>tdd", function()
		M.ui.select_todo_file("current", function(choice)
			if choice then
				M.ui.delete_todo_file(choice.path)
			end
		end)
	end, { desc = "TODO: 删除文件" })

	-------------------------------------------------------------------
	-- 自动同步：代码文件
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.lua", "*.rs", "*.go", "*.ts", "*.js", "*.py", "*.c", "*.cpp" },
		callback = function(args)
			vim.defer_fn(function()
				M.link.sync_code_links()
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
				M.link.sync_todo_links()
			end)
		end,
	})

	-- lazy load 标记状态渲染
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "lua", "rust", "go", "python", "javascript", "typescript", "c", "cpp" },
		callback = function(args)
			vim.schedule(function()
				M.link.render_code_status(args.buf)
			end)
		end,
	})

	-- TODO文件自动应用conceal和刷新
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "markdown" },
		callback = function(args)
			local bufname = vim.api.nvim_buf_get_name(args.buf)
			if bufname:match("%.todo%.md$") then
				vim.schedule(function()
					M.ui.apply_conceal(args.buf)
					M.ui.refresh(args.buf)
				end)
			end
		end,
	})
end

---------------------------------------------------------------------
-- 对外暴露 API
---------------------------------------------------------------------
-- 这些将在 setup 时被填充，但为了安全，我们在这里也做延迟加载
setmetatable(M, {
	__index = function(self, key)
		if key == "core" then
			rawset(self, key, require("todo.core"))
			return self.core
		elseif key == "render" then
			rawset(self, key, require("todo.render"))
			return self.render
		elseif key == "link" then
			rawset(self, key, require("todo.link"))
			return self.link
		elseif key == "ui" then
			rawset(self, key, require("todo.ui"))
			return self.ui
		elseif key == "manager" then
			rawset(self, key, require("todo.manager"))
			return self.manager
		end
	end,
})

return M
