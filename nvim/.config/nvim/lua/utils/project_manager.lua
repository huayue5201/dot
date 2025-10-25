local json_store = require("utils.json_store")
local M = {}

-- ================================
-- 配置
-- ================================
local config = {
	file_path = vim.fn.stdpath("cache") .. "/user_projects.json",
	max_recent = 50,
	project_files = { ".git", "Cargo.toml", "Makefile", "CMakeLists.txt", "platformio.ini" },
}

local store = json_store:new({
	file_path = config.file_path,
	default_data = { projects = {}, recent = {} },
})

-- ================================
-- 工具函数
-- ================================
local function normalize_path(path)
	if not path or path == "" then
		return nil
	end
	return vim.fn.fnamemodify(vim.fn.expand(path), ":p"):gsub("\n", "")
end

local function find_project_root()
	local cwd = vim.fn.getcwd()
	local path = cwd
	while path and path ~= "/" do
		for _, file in ipairs(config.project_files) do
			if vim.fn.glob(path .. "/" .. file) ~= "" then
				return path
			end
		end
		path = vim.fn.fnamemodify(path, ":h")
	end
	return cwd
end

local function update_recent(project)
	local state = store:load()
	state.recent = vim.tbl_filter(function(p)
		return p ~= project
	end, state.recent)
	table.insert(state.recent, 1, project)
	while #state.recent > config.max_recent do
		table.remove(state.recent)
	end
	store:save(state)
end

-- ================================
-- 添加项目
-- ================================
function M.add_project()
	local project = normalize_path(find_project_root())
	if not project or vim.fn.isdirectory(project) == 0 then
		vim.notify("❌ 无效目录: " .. tostring(project), vim.log.levels.WARN)
		return
	end

	local state = store:load()
	if not vim.tbl_contains(state.projects, project) then
		table.insert(state.projects, project)
		store:save(state)
		vim.notify("✅ 已添加项目: " .. project)
	else
		vim.notify("ℹ️ 项目已存在: " .. project)
	end
end

-- ================================
-- 删除项目（交互式选择）
-- ================================
function M.remove_project_interactive()
	local state = store:load()
	if #state.projects == 0 then
		vim.notify("⚠️ 项目列表为空", vim.log.levels.INFO)
		return
	end

	vim.ui.select(state.projects, {
		prompt = "🗑️ 选择要删除的项目: ",
	}, function(project)
		if not project then
			vim.notify("已取消删除", vim.log.levels.INFO)
			return
		end

		local ok = vim.fn.input("⚠️ 确定删除 [" .. project .. "] 吗? (y/n): "):lower()
		if ok == "y" then
			state.projects = vim.tbl_filter(function(p)
				return p ~= project
			end, state.projects)
			store:save(state)
			vim.notify("🗑️ 已删除项目: " .. project, vim.log.levels.WARN)
		else
			vim.notify("已取消删除", vim.log.levels.INFO)
		end
	end)
end

-- ================================
-- 打开项目（独立 Tab）
-- ================================
local function open_project_in_tab(project)
	if not project or vim.fn.isdirectory(project) == 0 then
		return
	end

	local curbuf = vim.api.nvim_get_current_buf()
	local bufname = vim.api.nvim_buf_get_name(curbuf)
	local is_empty = (bufname == "" or bufname:match("^term://")) and vim.api.nvim_buf_line_count(curbuf) <= 1

	if not is_empty then
		vim.cmd("tabnew")
	end

	vim.t.project_root = project -- 每个 tab 记录自己的项目根
	vim.cmd("tcd " .. vim.fn.fnameescape(project))
	update_recent(project)
end

-- ================================
-- fzf 链式项目/文件选择
-- ================================
function M.pick_project_and_file()
	local state = store:load()
	if #state.projects == 0 then
		vim.notify("⚠️ 项目列表为空，请先添加项目", vim.log.levels.INFO)
		return
	end

	vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
		source = state.projects,
		options = {
			"--prompt",
			"📁 选择项目: ",
			"--ansi",
		},
		sink = function(selected_project)
			local project = type(selected_project) == "table" and selected_project[1] or selected_project
			if not project or vim.fn.isdirectory(project) == 0 then
				return
			end

			open_project_in_tab(project)

			local files = vim.fn.systemlist({ "fd", "--type", "f", ".", project })
			if #files == 0 then
				vim.notify("⚠️ 项目中未找到文件", vim.log.levels.INFO)
				return
			end

			vim.fn["fzf#run"](vim.fn["fzf#wrap"]({
				source = files,
				options = { "--prompt", "📄 选择文件: " },
				sink = function(selected_file)
					local file = type(selected_file) == "table" and selected_file[1] or selected_file
					if file and vim.fn.filereadable(file) == 1 then
						vim.cmd("edit " .. vim.fn.fnameescape(file))
						vim.cmd("tcd " .. vim.fn.fnameescape(project)) -- 保持在项目根目录
					end
				end,
			}))
		end,
	}))
end

-- ================================
-- 自动切换目录 (TabEnter + BufEnter)
-- ================================
vim.api.nvim_create_autocmd({ "TabEnter", "BufEnter" }, {
	callback = function()
		if vim.t.project_root and vim.fn.isdirectory(vim.t.project_root) == 1 then
			vim.cmd("tcd " .. vim.fn.fnameescape(vim.t.project_root))
			return
		end

		-- 自动检测当前 buffer 属于哪个项目
		local bufname = vim.api.nvim_buf_get_name(0)
		if bufname ~= "" then
			local state = store:load()
			for _, project in ipairs(state.projects or {}) do
				if bufname:find(project, 1, true) == 1 then
					vim.t.project_root = project
					vim.cmd("tcd " .. vim.fn.fnameescape(project))
					return
				end
			end
		end
	end,
})

-- ================================
-- 注册命令
-- ================================
function M.setup()
	vim.api.nvim_create_user_command("ProjectAdd", function()
		M.add_project()
	end, {})

	vim.api.nvim_create_user_command("ProjectRemove", function()
		M.remove_project_interactive()
	end, {})

	vim.api.nvim_create_user_command("ProjectOpen", function()
		M.pick_project_and_file()
	end, {})
end

vim.keymap.set("n", "<leader>fp", "<cmd>ProjectOpen<cr>", { silent = true, desc = "项目索引" })
vim.keymap.set("n", "<leader>rp", "<cmd>ProjectRemove<cr>", { silent = true, desc = "删除项目索引" })
vim.keymap.set("n", "<leader>sp", "<cmd>ProjectAdd<cr>", { silent = true, desc = "添加项目索引" })
return M
