-- 获取当前项目的名称（优先使用 cd 到的根目录，其次是 Git 仓库根目录）
local function get_project_name()
	local current_dir = vim.fn.getcwd()
	local git_root = vim.fn.trim(vim.fn.system("git rev-parse --show-toplevel"))
	if vim.fn.isdirectory(current_dir) == 1 and git_root == "" then
		return vim.fn.fnamemodify(current_dir, ":p:t") -- 只返回目录的最后一部分
	elseif git_root ~= "" then
		return vim.fn.fnamemodify(git_root, ":p:t") -- 只返回 Git 根目录的最后一部分
	else
		return vim.fn.fnamemodify(current_dir, ":p:t") -- 只返回当前目录的最后一部分
	end
end

local function save_session()
	local session_dir = vim.fn.expand("~/.local/share/nvim/sessions")
	local project_name = get_project_name()
	local unique_id = vim.fn.sha256(vim.fn.getcwd()):sub(1, 8)
	local session_file = session_dir .. "/" .. project_name .. "_" .. unique_id .. "_session.vim"

	-- 如果会话目录不存在，创建该目录
	if vim.fn.isdirectory(session_dir) == 0 then
		vim.fn.mkdir(session_dir, "p")
	end

	-- 检查是否已经存在会话文件，如果存在则覆盖
	if vim.fn.filereadable(session_file) == 1 then
		print("覆盖现有会话文件： " .. session_file)
		-- 删除已存在的会话文件
		vim.fn.delete(session_file)
	end

	-- 获取当前会话文件的修改时间
	local current_time = vim.fn.getftime(session_file)
	local current_content = vim.fn.execute("mksession! " .. session_file)
	if current_time > 0 and current_content == vim.fn.readfile(session_file) then
		print("没有更改，未保存会话。")
		return
	end

	-- 直接保存会话，确保会话数据保存在正确的路径下
	vim.cmd("mksession! " .. session_file)
	print("会话已保存： " .. session_file)
end

-- 加载会话
local function load_session(session_file)
	if vim.fn.filereadable(session_file) == 1 then
		vim.defer_fn(function()
			print("Loading session from: " .. session_file)
			vim.cmd("source " .. session_file)
			print("Session loaded from: " .. session_file)
		end, 50)
	else
		print("No session found at: " .. session_file)
	end
end

-- 恢复当前项目的会话
local function restore_current_session()
	local session_dir = vim.fn.expand("~/.local/share/nvim/sessions")
	local project_name = get_project_name()
	local unique_id = vim.fn.sha256(vim.fn.getcwd()):sub(1, 8)
	local session_file = session_dir .. "/" .. project_name .. "_" .. unique_id .. "_session.vim"

	if vim.fn.filereadable(session_file) == 1 then
		load_session(session_file)
	else
		vim.notify("No session found for current project: " .. project_name, vim.log.levels.WARN)
	end
end

-- 提供 vim.ui.select 选择会话
local function select_session()
	local session_dir = vim.fn.expand("~/.local/share/nvim/sessions")
	local session_files = vim.fn.glob(session_dir .. "/*_session.vim", false, true)

	if #session_files == 0 then
		print("No saved sessions found.")
		return
	end

	local session_names = {}
	for _, file in ipairs(session_files) do
		table.insert(session_names, vim.fn.fnamemodify(file, ":t:r"))
	end

	vim.ui.select(session_names, {
		prompt = "Select a session to load:",
	}, function(selected)
		if selected then
			local selected_session = session_files[vim.fn.index(session_names, selected) + 1]
			load_session(selected_session)
		else
			print("No session selected.")
		end
	end)
end

-- 异步清理无用的会话文件
local function clean_unused_sessions()
	local session_dir = vim.fn.expand("~/.local/share/nvim/sessions")
	local session_files = vim.fn.glob(session_dir .. "/*_session.vim", false, true)

	if #session_files == 0 then
		print("No saved sessions found.")
		return
	end

	vim.defer_fn(function()
		for _, session_file in ipairs(session_files) do
			local project_dir = vim.fn.fnamemodify(session_file, ":p:h")
			if vim.fn.isdirectory(project_dir) == 0 then
				vim.fn.delete(session_file)
				print("Deleted unused session: " .. session_file)
			end
		end
	end, 100)
end

-- 设置会话选项（可根据需求调整）
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"

-- -- 自动保存会话（退出时保存会话）
-- vim.api.nvim_create_autocmd("VimLeave", {
-- 	callback = function()
-- 		save_session()
-- 	end,
-- })

-- 清理无用会话文件的命令映射
vim.keymap.set("n", "<leader>sc", function()
	clean_unused_sessions()
end, { silent = true })

-- 按键映射：手动保存会话
vim.keymap.set("n", "<leader>ss", function()
	save_session()
end, { silent = true })

-- 按键映射：手动选择并加载会话
vim.keymap.set("n", "<leader>sl", function()
	select_session()
end, { silent = true })

-- 按键映射：恢复当前项目的会话
vim.keymap.set("n", "<leader>sr", function()
	restore_current_session()
end, { silent = true })
