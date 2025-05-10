local session_dir = vim.fn.expand("~/.local/share/nvim/sessions")

-- 确保目录存在
if vim.fn.isdirectory(session_dir) == 0 then
	vim.fn.mkdir(session_dir, "p")
end

-- 获取项目名称
local function get_project_name()
	local cwd = vim.fn.getcwd()

	-- Git 仓库：返回 "repo (branch)"
	local git_root = vim.fn.systemlist("git rev-parse --show-toplevel")
	if vim.v.shell_error == 0 and #git_root > 0 then
		local repo = vim.fn.fnamemodify(git_root[1], ":t")
		local branch = vim.fn.trim(vim.fn.system("git rev-parse --abbrev-ref HEAD"))
		if branch ~= "" then
			return ("%s (%s)"):format(repo, branch)
		end
		return repo
	end

	-- 检查 Rust 项目 (Cargo.toml)
	local cargo_toml = cwd .. "/Cargo.toml"
	if vim.fn.filereadable(cargo_toml) == 1 then
		for _, line in ipairs(vim.fn.readfile(cargo_toml)) do
			local name = line:match("^name%s*=%s*[\"'](.+)[\"']")
			if name then
				return name
			end
		end
	end

	-- 检查 Makefile 中的 PROJECT / PROJECT_NAME 变量
	local makefile = cwd .. "/Makefile"
	if vim.fn.filereadable(makefile) == 1 then
		for _, line in ipairs(vim.fn.readfile(makefile)) do
			local name = line:match("^%s*PROJECT[_NAME]*%s*=%s*(.+)")
			if name then
				return vim.fn.trim(name)
			end
		end
	end

	-- 否则使用当前目录名
	return vim.fn.fnamemodify(cwd, ":t")
end

-- 会话路径生成器
local function get_session_file()
	local project = get_project_name()
	local hash = vim.fn.sha256(vim.fn.getcwd()):sub(1, 8)
	local filename = ("%s_%s_session.vim"):format(project, hash)
	return session_dir .. "/" .. filename
end

-- 保存会话
local function save_session()
	local path = get_session_file()
	-- vim.api.nvim_command("mksession! " .. vim.fn.fnameescape(path))
	vim.fn.execute("mksession! " .. vim.fn.fnameescape(path))
	vim.notify("会话已保存: " .. path)
end

-- 加载会话
local function load_session(path)
	if vim.fn.filereadable(path) == 1 then
		vim.fn.execute("source " .. vim.fn.fnameescape(path))
		vim.notify("加载会话: " .. path)
	else
		vim.notify("未找到会话: " .. path, vim.log.levels.WARN)
	end
end

-- 恢复当前项目的会话
local function restore_current_session()
	load_session(get_session_file())
end

-- 删除指定会话
local function delete_session(path)
	if vim.fn.filereadable(path) == 1 then
		vim.fn.delete(path)
		vim.notify("删除会话: " .. path)
	else
		vim.notify("会话文件不存在: " .. path, vim.log.levels.WARN)
	end
end

-- 选择操作：加载或删除
local function select_session_action(action)
	local files = vim.fn.glob(session_dir .. "/*_session.vim", false, true)
	if #files == 0 then
		vim.notify("没有保存的会话")
		return
	end

	local labels = vim.tbl_map(function(path)
		return vim.fn.fnamemodify(path, ":t")
	end, files)

	vim.ui.select(labels, { prompt = "选择会话：" }, function(choice)
		if not choice then
			return
		end
		local selected = session_dir .. "/" .. choice
		if action == "load" then
			load_session(selected)
		elseif action == "delete" then
			delete_session(selected)
		end
	end)
end

-- 清理不存在项目的会话（目录被删）
local function clean_unused_sessions()
	local files = vim.fn.glob(session_dir .. "/*_session.vim", false, true)
	for _, file in ipairs(files) do
		local stat = vim.loop.fs_stat(file)
		if not stat then
			vim.fn.delete(file)
			vim.notify("已清理失效会话: " .. file)
		end
	end
end

-- 键位绑定
vim.keymap.set("n", "<leader>ss", save_session, { desc = "保存会话" })
vim.keymap.set("n", "<leader>sr", restore_current_session, { desc = "恢复当前项目会话" })
vim.keymap.set("n", "<leader>sl", function()
	select_session_action("load")
end, { desc = "选择并加载会话" })
vim.keymap.set("n", "<leader>sd", function()
	select_session_action("delete")
end, { desc = "选择并删除会话" })
vim.keymap.set("n", "<leader>sc", clean_unused_sessions, { desc = "清理无效会话" })

-- 会话选项
vim.o.sessionoptions = "blank,buffers,curdir,folds,help,tabpages,winsize,winpos,terminal,localoptions"
