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

-- 配置存储
local config = vim.deepcopy(default_config)

-- 模块缓存（懒加载）
local modules = {
	core = nil,
	render = nil,
	link = nil,
	ui = nil,
	manager = nil,
}

---------------------------------------------------------------------
-- 懒加载函数
---------------------------------------------------------------------
local function load_module(name)
	if not modules[name] then
		if name == "core" then
			modules[name] = require("todo2.core")
		elseif name == "render" then
			modules[name] = require("todo2.render")
		elseif name == "link" then
			modules[name] = require("todo2.link")
		elseif name == "ui" then
			modules[name] = require("todo2.ui")
		elseif name == "manager" then
			modules[name] = require("todo2.manager")
		end
	end
	return modules[name]
end

-- 使用元表实现自动懒加载
setmetatable(M, {
	__index = function(self, key)
		if modules[key] then
			return modules[key]
		end

		-- 尝试懒加载
		if key == "core" or key == "render" or key == "link" or key == "ui" or key == "manager" then
			return load_module(key)
		end

		return nil
	end,
})

---------------------------------------------------------------------
-- 配置相关函数
---------------------------------------------------------------------
function M.get_config()
	return config
end

function M.get_link_config()
	return config.link or default_config.link
end

---------------------------------------------------------------------
-- 插件初始化
---------------------------------------------------------------------
function M.setup(user_config)
	-- 合并用户配置和默认配置
	if user_config then
		config = vim.tbl_deep_extend("force", vim.deepcopy(default_config), user_config)
	end

	-------------------------------------------------------------------
	-- 应用配置到 link 模块
	-------------------------------------------------------------------
	if config.link then
		local link_module = load_module("link")
		if link_module.setup then
			link_module.setup(config.link)
		end
	end

	-------------------------------------------------------------------
	-- 高亮组（删除线、灰色）
	-------------------------------------------------------------------
	vim.cmd([[
        highlight TodoCompleted guifg=#888888 gui=italic
        highlight TodoStrikethrough gui=strikethrough cterm=strikethrough
    ]])

	-------------------------------------------------------------------
	-- 全局按键映射（双向链接） - 延迟加载实现
	-------------------------------------------------------------------

	-- 创建链接的延迟按键映射
	vim.keymap.set("n", "<leader>tda", function()
		local link_module = load_module("link")
		if link_module.create_link then
			link_module.create_link()
		end
	end, { desc = "创建代码→TODO 链接" })

	-- 动态跳转的延迟按键映射
	vim.keymap.set("n", "gj", function()
		local link_module = load_module("link")
		if link_module.jump_dynamic then
			link_module.jump_dynamic()
		end
	end, { desc = "动态跳转 TODO <-> 代码" })

	-- 双链标记管理的延迟按键映射
	vim.keymap.set("n", "<leader>tdq", function()
		local manager_module = load_module("manager")
		if manager_module.show_project_links_qf then
			manager_module.show_project_links_qf()
		end
	end, { desc = "显示所有双链标记 (QuickFix)" })

	vim.keymap.set("n", "<leader>tdl", function()
		local manager_module = load_module("manager")
		if manager_module.show_buffer_links_loclist then
			manager_module.show_buffer_links_loclist()
		end
	end, { desc = "显示当前缓冲区双链标记 (LocList)" })

	vim.keymap.set("n", "<leader>tdr", function()
		local manager_module = load_module("manager")
		if manager_module.fix_orphan_links_in_buffer then
			manager_module.fix_orphan_links_in_buffer()
		end
	end, { desc = "修复当前缓冲区孤立的标记" })

	vim.keymap.set("n", "<leader>tdw", function()
		local manager_module = load_module("manager")
		if manager_module.show_stats then
			manager_module.show_stats()
		end
	end, { desc = "显示双链标记统计" })

	-------------------------------------------------------------------
	-- 悬浮预览（按 K）的延迟按键映射
	-------------------------------------------------------------------
	vim.keymap.set("n", "<leader>tk", function()
		local link_module = load_module("link")
		local line = vim.fn.getline(".")

		if line:match("TODO:ref:(%w+)") then
			if link_module.preview_todo then
				link_module.preview_todo()
			end
		elseif line:match("{#(%w+)}") then
			if link_module.preview_code then
				link_module.preview_code()
			end
		else
			vim.lsp.buf.hover()
		end
	end, { desc = "预览 TODO 或代码" })

	-------------------------------------------------------------------
	-- TODO 文件管理 - 多种窗口模式的延迟按键映射
	-------------------------------------------------------------------

	-- 浮窗打开
	vim.keymap.set("n", "<leader>tdo", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.select_todo_file then
			ui_module.select_todo_file("current", function(choice)
				if choice then
					ui_module.open_todo_file(choice.path, "float", 1, { enter_insert = false })
				end
			end)
		end
	end, { desc = "TODO: 浮窗打开" })

	-- 水平分割打开
	vim.keymap.set("n", "<leader>tds", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.select_todo_file then
			ui_module.select_todo_file("current", function(choice)
				if choice then
					ui_module.open_todo_file(choice.path, "split", 1, {
						enter_insert = false,
						split_direction = "horizontal",
					})
				end
			end)
		end
	end, { desc = "TODO: 水平分割打开" })

	-- 垂直分割打开
	vim.keymap.set("n", "<leader>tdv", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.select_todo_file then
			ui_module.select_todo_file("current", function(choice)
				if choice then
					ui_module.open_todo_file(choice.path, "split", 1, {
						enter_insert = false,
						split_direction = "vertical",
					})
				end
			end)
		end
	end, { desc = "TODO: 垂直分割打开" })

	-- 编辑模式打开
	vim.keymap.set("n", "<leader>tde", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.select_todo_file then
			ui_module.select_todo_file("current", function(choice)
				if choice then
					ui_module.open_todo_file(choice.path, "edit", 1, { enter_insert = false })
				end
			end)
		end
	end, { desc = "TODO: 编辑模式打开" })

	-- 创建 TODO 文件
	vim.keymap.set("n", "<leader>tdn", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.create_todo_file then
			ui_module.create_todo_file()
		end
	end, { desc = "TODO: 创建文件" })

	-- 删除 TODO 文件
	vim.keymap.set("n", "<leader>tdd", function()
		local ui_module = load_module("ui")
		if ui_module and ui_module.select_todo_file then
			ui_module.select_todo_file("current", function(choice)
				if choice and ui_module.delete_todo_file then
					ui_module.delete_todo_file(choice.path)
				end
			end)
		end
	end, { desc = "TODO: 删除文件" })

	-------------------------------------------------------------------
	-- 自动同步：代码文件（延迟加载实现）
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.lua", "*.rs", "*.go", "*.ts", "*.js", "*.py", "*.c", "*.cpp" },
		callback = function(args)
			vim.defer_fn(function()
				local link_module = load_module("link")
				if link_module and link_module.sync_code_links then
					link_module.sync_code_links()
				end
			end, 0)
		end,
	})

	-------------------------------------------------------------------
	-- 自动同步：TODO 文件（延迟加载实现）
	-------------------------------------------------------------------
	vim.api.nvim_create_autocmd("BufWritePost", {
		pattern = { "*.todo.md", "*.todo", "todo.txt" },
		callback = function()
			vim.schedule(function()
				local link_module = load_module("link")
				if link_module and link_module.sync_todo_links then
					link_module.sync_todo_links()
				end
			end)
		end,
	})

	-- lazy load 标记状态渲染
	vim.api.nvim_create_autocmd("FileType", {
		pattern = { "lua", "rust", "go", "python", "javascript", "typescript", "c", "cpp" },
		callback = function(args)
			vim.schedule(function()
				local link_module = load_module("link")
				if link_module and link_module.render_code_status then
					link_module.render_code_status(args.buf)
				end
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
					local ui_module = load_module("ui")
					if ui_module and ui_module.apply_conceal then
						ui_module.apply_conceal(args.buf)
					end
					if ui_module and ui_module.refresh then
						ui_module.refresh(args.buf)
					end
				end)
			end
		end,
	})
end

---------------------------------------------------------------------
-- 工具函数：重新加载所有模块（用于调试）
---------------------------------------------------------------------
function M.reload_all()
	-- 清除所有缓存的模块
	for name, _ in pairs(modules) do
		modules[name] = nil
		package.loaded["todo." .. name] = nil
	end

	-- 清除子模块
	package.loaded["todo.core"] = nil
	package.loaded["todo.render"] = nil
	package.loaded["todo.link"] = nil
	package.loaded["todo.ui"] = nil
	package.loaded["todo.manager"] = nil
	package.loaded["todo.store"] = nil

	-- 清除link子模块
	package.loaded["todo.link.utils"] = nil
	package.loaded["todo.link.creator"] = nil
	package.loaded["todo.link.jumper"] = nil
	package.loaded["todo.link.renderer"] = nil
	package.loaded["todo.link.syncer"] = nil
	package.loaded["todo.link.preview"] = nil
	package.loaded["todo.link.cleaner"] = nil
	package.loaded["todo.link.searcher"] = nil

	-- 清除ui子模块
	package.loaded["todo.ui.conceal"] = nil
	package.loaded["todo.ui.constants"] = nil
	package.loaded["todo.ui.file_manager"] = nil
	package.loaded["todo.ui.keymaps"] = nil
	package.loaded["todo.ui.operations"] = nil
	package.loaded["todo.ui.statistics"] = nil
	package.loaded["todo.ui.window"] = nil

	-- 清除core子模块
	package.loaded["todo.core.parser"] = nil
	package.loaded["todo.core.stats"] = nil
	package.loaded["todo.core.sync"] = nil
	package.loaded["todo.core.toggle"] = nil

	print("🔄 TODO 插件模块已重新加载")
end

---------------------------------------------------------------------
-- 工具函数：获取模块加载状态
---------------------------------------------------------------------
function M.get_module_status()
	local status = {}
	for name, module in pairs(modules) do
		status[name] = module ~= nil
	end
	return status
end

return M
