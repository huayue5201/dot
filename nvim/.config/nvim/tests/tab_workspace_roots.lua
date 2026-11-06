-- 用户视角的行为测试：一个工作区可以挂多个根（主根 = cwd，辅根 = 附加上去的目录）。
--
--   nvim --headless -u NONE -l tests/tab_workspace_roots.lua
--
-- 覆盖：
--   * <leader>lw+ 的语义：attach 后出现在根列表里，重复加不会出现两次
--   * 主根不能被当成辅助根加进来；不存在的目录加不进来
--   * <leader>lw- 的语义：detach 只摘辅助根，主根还在
--   * :tcd 换主根后：新主根若在辅助根里会被摘掉，旧主根不会自动降级成辅助根
--   * 会话会记住辅助根（export 带 aux），载入后恢复；没有辅助根的 tab 不写 aux
--   * neo-tree 的 workspace 源：顶层节点 = 主根 + 辅助根，展开根后是真实目录内容
--
-- 退出码：有失败 1，全通过 0。

vim.opt.rtp:prepend(vim.fn.getcwd())

local pack_root = vim.fn.stdpath("data") .. "/site/pack/core/opt/"
local neotree_dir = pack_root .. "neo-tree.nvim"
-- neo-tree 依赖 nui.nvim / plenary.nvim 等：把 pack 里的插件都放进 rtp
for _, dir in ipairs(vim.fn.glob(pack_root .. "*", false, true)) do
	if vim.fn.isdirectory(dir) == 1 then
		vim.opt.rtp:prepend(dir)
	end
end

local State = require("feat.tab_workspace.state")
local session = require("feat.tab_workspace.session")
local roots = require("feat.tab_workspace.roots")

local fails = {}
local function check(cond, msg)
	if not cond then
		fails[#fails + 1] = msg
	end
end

local function note(msg)
	io.stdout:write("  · " .. msg .. "\n")
end

-- 两个真实目录（辅助根必须存在，且要有内容才能验证展开）
local tmp = vim.fn.tempname()
local root_a = tmp .. "/项目"
local root_b = tmp .. "/另一个项目"
vim.fn.mkdir(root_a .. "/src", "p")
vim.fn.mkdir(root_b .. "/仓库", "p")
vim.fn.writefile({ "x" }, root_a .. "/src/main.lua")
vim.fn.writefile({ "y" }, root_b .. "/仓库/lib.rs")

-- macOS 的 /var 是 /private/var 的软链：和 roots.norm() 用同一套规范化，否则路径对不上
local function real(p)
	return vim.uv.fs_realpath(p) or p
end
tmp, root_a, root_b = real(tmp), real(root_a), real(root_b)

local function cleanup()
	vim.fn.delete(tmp, "rf")
end

--------------------------------------------------------------------------
-- 1. attach / detach
--------------------------------------------------------------------------
vim.cmd.tcd(root_a)
local tab = vim.api.nvim_get_current_tabpage()
check(#roots.all(tab) == 1, "刚开始只有主根，实际 " .. #roots.all(tab))

local ok, err = roots.attach(tab, root_b)
check(ok, "附加辅助根失败: " .. tostring(err))
check(#roots.all(tab) == 2, "附加后应有 2 个根")
check(roots.all(tab)[1] == root_a and roots.all(tab)[2] == root_b, "主根在前、辅助根在后")
note("attach: " .. table.concat(
	vim.tbl_map(function(d)
		return vim.fn.fnamemodify(d, ":t")
	end, roots.all(tab)),
	" + "
))

local ok2, why = roots.attach(tab, root_b .. "/")
check(not ok2, "重复附加应被拒绝（尾部斜杠也算同一个）: " .. tostring(why))
check(#roots.all(tab) == 2, "重复附加不应改变根列表")

check(not roots.attach(tab, root_a), "主根不能当辅助根附加")
check(not roots.attach(tab, tmp .. "/不存在"), "不存在的目录不能附加")

check(roots.detach(tab, root_b) == true, "移除辅助根应成功")
check(#roots.all(tab) == 1, "移除后只剩主根")
check(roots.detach(tab, root_a) == false, "主根不是辅助根，移除应失败")

--------------------------------------------------------------------------
-- 2. 主根切换后的对齐
--------------------------------------------------------------------------
roots.attach(tab, root_b)
vim.cmd.tcd(root_b)
check(#roots.aux(tab) == 0, "新主根原本是辅助根，切过去后应从辅助根里摘掉")
check(#roots.all(tab) == 1, "对齐后只有主根 " .. root_b)

vim.cmd.tcd(root_a)
check(#roots.aux(tab) == 1 and roots.aux(tab)[1] == root_b, "切回 A 后 B 仍是辅助根")
check(not vim.tbl_contains(roots.aux(tab), root_a), "主根不会出现在辅助根列表里")
check(roots.find_root(tab, root_a .. "/src/main.lua") == root_a, "find_root 命中主根内的文件")
check(roots.find_root(tab, root_b .. "/仓库/lib.rs") == root_b, "find_root 命中辅助根内的文件")
check(roots.find_root(tab, tmp .. "/别处") == nil, "根外的路径不命中")

--------------------------------------------------------------------------
-- 3. 会话记住辅助根
--------------------------------------------------------------------------
vim.bo.buflisted = true
vim.cmd.edit(root_a .. "/src/main.lua")
State.claim(tab, vim.api.nvim_get_current_buf())

local data = session.export()
check(data.v == 2, "会话格式版本")
check(type(data.list) == "table" and #data.list >= 1, "会话里应有 tab 列表")
local entry = data.list[1]
check(entry.root ~= nil, "会话条目带 root")
check(type(entry.aux) == "table" and entry.aux[1] == root_b, "会话条目带辅助根")

-- 恢复：先把当前 tab 的辅助根清空，再从会话装回去
roots.clear(tab)
check(#roots.aux(tab) == 0, "清空后没有辅助根")
session.restore(data)
check(#roots.aux(tab) == 1 and roots.aux(tab)[1] == root_b, "会话恢复后辅助根回来了")

-- 没有辅助根时不写 aux（会话文件保持干净）
vim.cmd("tabnew")
vim.cmd.tcd(root_b)
local data2 = session.export()
check(data2.list[#data2.list].aux == nil, "没有辅助根的 tab 不写 aux 字段")
vim.cmd("tabclose")
check(vim.api.nvim_tabpage_is_valid(tab), "回到第一个 tab")

--------------------------------------------------------------------------
-- 4. neo-tree 的 workspace 源
--------------------------------------------------------------------------
if vim.fn.isdirectory(neotree_dir) == 0 then
	note("skip neo-tree: 未安装")
elseif not pcall(require, "neo-tree") then
	note("skip neo-tree: require 失败")
else
	local ok_nt = pcall(function()
		require("neo-tree").setup({
			sources = { "filesystem", "feat.tab_workspace.neo_tree" },
			hide_root_node = true,
			retain_hidden_root_indent = true,
			workspace = {
				window = { width = 30 },
				renderers = {
					directory = vim.list_extend(
						{ { "indent" }, { "workspace_badge" } },
						require("neo-tree.defaults").renderers.directory
					),
				},
			},
		})
	end)
	check(ok_nt, "neo-tree.setup 接受 workspace 源")

	local source = require("feat.tab_workspace.neo_tree")
	check(source.name == "workspace", "源名为 workspace")
	check(type(source.navigate) == "function" and type(source.setup) == "function", "源接口齐全")

	require("feat.tab_workspace").setup()
	roots.attach(tab, root_b)
	require("neo-tree.command").execute({ source = "workspace", action = "show", position = "left" })

	local manager = require("neo-tree.sources.manager")
	local state = manager.get_state("workspace")
	local function root_nodes()
		if not state or not state.tree then
			return {}
		end
		-- hide_root_node=true：合成根被 skip，真实根是它的子节点
		local nodes = state.tree:get_nodes()
		local root = nodes[1]
		if root and root.id == "workspace://roots" then
			return state.tree:get_nodes(root.id) or {}
		end
		return nodes
	end
	local ok_wait = vim.wait(2000, function()
		return #root_nodes() >= 2
	end, 20)
	check(ok_wait, "workspace 树渲染出多个根节点")

	if state and state.tree then
		local ids = {}
		for _, node in ipairs(root_nodes()) do
			ids[#ids + 1] = node.id
		end
		check(vim.tbl_contains(ids, root_a), "顶层包含主根 " .. root_a)
		check(vim.tbl_contains(ids, root_b), "顶层包含辅助根 " .. root_b)

		-- 展开辅助根 → 出现真实子节点
		local node = state.tree:get_node(root_b)
		check(node ~= nil, "能取到辅助根节点")
		if node then
			local ok_toggle, toggle_err = pcall(source.toggle_directory, state, node)
			check(ok_toggle, "展开辅助根不报错: " .. tostring(toggle_err))
			vim.wait(1500, function()
				return node:has_children()
			end, 20)
			check(node:has_children(), "展开辅助根后有子节点")
			local child = node:get_child_ids()[1]
			check(type(child) == "string" and child:find(tmp, 1, true) ~= nil, "子节点是真实路径")
			check(child ~= nil and child:find("仓库", 1, true) ~= nil, "子节点就是 仓库")
		end
	end
	pcall(vim.cmd, "Neotree close")
end

--------------------------------------------------------------------------
cleanup()
if #fails == 0 then
	print("ok: tab_workspace_roots")
	vim.cmd("qall!")
	os.exit(0)
else
	for _, msg in ipairs(fails) do
		io.stderr:write("FAIL: " .. msg .. "\n")
	end
	vim.cmd("qall!")
	os.exit(1)
end
