-- 项目概览：一次看清「这仓库是什么、有多大、怎么组织、最近在动什么、怎么构建、有什么约定」。
--
--   :Project        精简版（身份 / 规模 / 结构 / 活跃区 / 构建入口）
--   :Project!       完整版（再加 依赖 / 约定 / 规模细节）
--   <leader>ii      打开精简版（i = info；<leader>p 是 yanky 的粘贴前缀，别抢）
-- 窗口内：q / <Esc> 关闭，t 精简⇄完整，r 重新采集，gd 跳到光标下的文件/目录。
-- 非 git 目录也能用：直接按目录统计（跳过 node_modules/target/dist 这类依赖与产物）。
--
-- 为什么自己写：这类需求分散在 tokei 插件（只管行数）、gitsigns（只管 diff）、
-- neogit（只管提交）里，价值恰恰在「一屏、一次、按阅读顺序排好版」。
--
-- 实现要点：
--   * 采集走 vim.system：重活（tokei / git log）并行异步，结果回主线程渲染；
--     按 toplevel + HEAD 缓存在内存里，t 切换档位不重新跑命令。
--   * 语言行数优先 tokei（扣注释/空行、语言识别准），没装自动回落 git ls-files + wc -l
--     （含注释与空行、按扩展名猜语言），报告里会标明数据来源。
--   * 「活跃区」= 最近 90 天 git log 改动次数排序。新项目真正该先读的通常不是 README
--     吹的架构，而是最近还在动的文件。
--   * buffer 是 buftype=nofile 的 markdown（只读，可 yank / 搜索 / gd 跳转），并主动
--     关掉 markview 的原地渲染：这里是数据表，不需要二次排版。
--
-- 模块划分（都在 lua/local/project/ 下）：
--   util.lua    路径 / 行数格式化 / git 子进程 / 文件遍历 / 语言表
--   scan.lua    数据源解析（tokei / wc / license / README / 结构 / 活跃度 / recipe），纯函数
--   collect.lua 采集：文件清单 + 并行跑命令，组装成一份 data
--   render.lua  渲染：图标 + 分段 + 高亮
--   digest.lua  给 AI 的紧凑摘要
--   store.lua   跨模块共享状态（cache / state / last），用来断循环 require
--   ui.lua      窗口 / 按键 / 命令注册
--   init.lua    对外 API（open / ask / chat / bridge / digest / setup）

local util = require("local.project.util")
local store = require("local.project.store")
local collect_mod = require("local.project.collect")
local digest_mod = require("local.project.digest")
local ui = require("local.project.ui")

local git_sync = util.git_sync
local notify = util.notify
local resolve_root = util.resolve_root
local collect = collect_mod.collect

local M = {}

M.digest = digest_mod.digest

--- 打开/切换概览窗口
---@param opts? { full?: boolean, root?: string, force?: boolean }
function M.open(opts)
	return ui.open(opts)
end

--- 打开提问浮窗，摘要作为 <project-overview> 随问题一起发出（走 local.ai 的后端通道）
---@param data table
---@param opts? { prompt?: string }
local function ask_ai(data, opts)
	local ok, ai = pcall(require, "local.ai")
	if not ok then
		notify("没有 local.ai 模块，无法发问")
		return
	end
	local text, tokens = M.digest(data)
	local ok_ask, err = pcall(ai.ask, {
		note = ("概览 ~%d tok"):format(tokens),
		extension = { digest = text },
	})
	if not ok_ask then
		notify(tostring(err), vim.log.levels.WARN)
	end
end

--- 拿到「当前项目」的概览数据：概览 buffer 现成的 → 最近采集 → 否则就地采一次
---@param opts { root?: string }
---@param cb fun(data: table)
local function with_data(opts, cb)
	local st = store.state[vim.api.nvim_get_current_buf()]
	if st and st.data then
		return cb(st.data)
	end
	local root = resolve_root(opts.root)
	-- 刚看过概览（在任何 buffer 里）：直接用那份数据，省掉一次采集
	if store.last and store.last.root == root then
		return cb(store.last.data)
	end
	collect(root, opts.full == true, cb)
end

--- 就当前项目问 AI：在概览 buffer 里直接用现成数据，否则就地采集一次
---@param opts? { root?: string }
function M.ask(opts)
	opts = opts or {}
	with_data(opts, function(data)
		ask_ai(data, opts)
	end)
end

--- 把概览摘要塞进 codecompanion 的 chat（不自动提交，你在里面接着问）
---@param opts? { root?: string, adapter?: string }
function M.chat(opts)
	opts = opts or {}
	with_data(opts, function(data)
		local ok, cc = pcall(require, "codecompanion")
		if not ok then
			notify("没有 codecompanion 插件，改用 :ProjectAsk", vim.log.levels.WARN)
			return
		end
		local text, tokens = M.digest(data)
		local adapter = opts.adapter or "deepseek"
		local chat_opts = {
			-- auto_submit=false：只把摘要放进去，问题由你在 chat 里写（避免替你猜问题）
			auto_submit = false,
			messages = {
				{
					role = "user",
					content = ("（项目概览索引，供后续提问参考；只有结构与统计，不含源码）\n\n<project-overview>\n%s\n</project-overview>"):format(
						text
					),
				},
			},
		}
		if adapter ~= "default" then
			chat_opts.params = { adapter = adapter }
		end
		local sent, err = pcall(cc.chat, chat_opts)
		if not sent then
			notify("打开 codecompanion chat 失败：" .. tostring(err), vim.log.levels.WARN)
			return
		end
		notify(("概览已放进 chat（adapter=%s，~%d tok）：接着在里面提问即可"):format(adapter, tokens), vim.log.levels.INFO)
	end)
end

--- RPC 入口（给 pi 的 nvim 工具用）：按 root 返回紧凑摘要，不依赖当前 buffer
--- 优先顺序：最近采集 → 本根目录缓存（HEAD 相同）→ 现采一次（用 vim.wait 等到结果）
---@param req { root?: string, path?: string, full?: boolean, wait_ms?: number }
---@return table
function M.bridge(req)
	req = req or {}
	local root = resolve_root(req.root or req.path)
	local origin = "last"
	local data
	if store.last and store.last.root == root then
		data = store.last.data
	end
	if not data then
		local snapshot = store.cache[root]
		if snapshot and snapshot.head == git_sync(root, { "rev-parse", "--short", "HEAD" }) then
			data = snapshot.data
			origin = "cache"
		end
	end
	if not data then
		local got
		collect(root, req.full == true, function(d)
			got = d
		end)
		local wait_ms = tonumber(req.wait_ms) or 45000
		vim.wait(wait_ms, function()
			return got ~= nil
		end, 50)
		if not got then
			return {
				ok = false,
				error = ("采集 %s 超时（%dms）：大仓库首次跑 tokei 可能较慢，稍后重试"):format(root, wait_ms),
			}
		end
		data = got
		origin = "fresh"
		store.last = { root = root, data = data }
	end
	local text, tokens = M.digest(data)
	return {
		ok = true,
		action = "project",
		root = root,
		origin = origin,
		git = data.git,
		tokens = tokens,
		digest = text,
	}
end

function M.setup()
	ui.setup()
end

return M
