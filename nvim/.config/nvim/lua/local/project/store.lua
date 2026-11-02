-- 项目概览：跨模块共享的运行时状态。
-- 单独成文件是为了断掉 collect ⇄ ui ⇄ init 的循环 require。
return {
	cache = {}, -- root -> { head = string, data = table }
	state = {}, -- bufnr -> { root, data, full, paths, origin_win }
	last = nil, ---@type { root: string, data: table }|nil 最近一次采集（:ProjectAsk 复用，避免重复跑 tokei）
}
