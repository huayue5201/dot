-- ============================================================================
-- FIX:(image.nvim/markdown-inline-stack)
-- ============================================================================
-- 这是一个「临时修复」，不是插件功能。上游修好后整份删掉即可（含
-- plugins/tools/image.lua 里带 FIX 标记的那一行 require）。
--
-- 问题：markdown 里同一行出现多张图（典型：表格 `| ![a](a.png) | ![b](b.png) |`）
-- 时，image.nvim 的 markdown 集成按 treesitter 节点渲染
--   lua/image/utils/document.lua: render_image -> image:render({ x = start_col, y = start_row })
-- 两张图 start_row 相同，于是绝对 y 相同、整体重叠，只剩上层那张可见。
--
-- 曾试过的方案（都失败，别回头）：
--   1. render_offset_top + overlap：overlap 会被
--      lua/image/utils/virtual_padding.lua:37 get_overlap_scroll_position 用来把图「钉」
--      在 winrow + offset - scrolled_lines，滚动时图跟着 buffer 慢慢上移、压在正文上，
--      而 virt_lines 又无法被部分滚动（<C-e> 整块跳过），所以永远对不齐。
--   2. 按兄弟图宽度并排：treesitter 给的是字节列，CJK 表格里 | 左 | 右 | 的第二列
--      字节列 26 而屏幕列只有 7，且单元格只有几列宽，并排后图被压到不可读。
--
-- 本方案：把同一锚点行的多张图用 ImageMagick 纵向拼成一张 PNG，只渲染这一张。
--   * 像素高度直接相加，由 image.nvim 的 max_height_window_percentage 等比缩小，
--     两张图缩放一致，不会一张大一张小。
--   * 只有一个 extmark / 一份 virt_lines / 一次滚动重排，排版与普通单图完全一致。
--   * 合成结果缓存在 stdpath("cache")/image-stack/<hash>.png，key 含每个源的
--     路径 + mtime + size，源文件变了自动重拼。
--   * 组内非首张成员 render 直接返回 false（不画、不占行）；文件里的图变少时
--     及时 clear 掉旧的合成图。
--
-- 清理方式（上游修复后）：
--   1. 删除 lua/fix/image_nvim_markdown_image_stack.lua
--   2. 删除 plugins/tools/image.lua 里带 FIX(markdown-inline-stack) 注释的那一行
-- ============================================================================
local M = {}

-- 守卫元数据：见 lua/fix/init.lua 顶部说明；:FixStatus 查看状态
M.meta = {
	id = "image.nvim/markdown-inline-stack",
	title = "markdown 同一行多张图（表格单元格）重叠：只按 start_row 定位，未处理同行的 x 偏移",
	plugin = "image.nvim",
	baseline_rev = "365e2ac",
	buggy = {
		{ file = "lua/image/utils/document.lua", contains = "y = item.match.range.start_row," },
	},
	cleanup = { "同时删掉 lua/fix/image_nvim_markdown_image_stack.lua 和 plugins/tools/image.lua 里的 require" },
}

M._installed = false
-- 调试开关：在 lua 里 _G.bp_debug = true 后，渲染决策会写进 _G.bp
local function trace(fmt, ...)
	if not _G.bp_debug then
		return
	end
	_G.bp = _G.bp or {}
	_G.bp[#_G.bp + 1] = fmt:format(...)
end

M._installed = false
M._composites = {} -- key -> Image
M._building = {} -- key -> true

local CACHE_SUBDIR = "image-stack"
local MAX_SOURCE_WIDTH = 2000
local BUILD_RETRY_LIMIT = 20

---尺寸/位置只对这些图有意义
---@param img table
local function is_stack_candidate(img)
	return img.buffer ~= nil and img.inline and img.with_virtual_padding and img.geometry ~= nil
end

---同一锚点行、同 buffer 同 namespace 的所有内联图（含自身），按 x 升序
---@param img table
---@param row integer
local function group_of(img, row)
	local group = { img }
	for _, other in pairs(img.global_state.images) do
		if
			is_stack_candidate(other)
			and other ~= img
			and other.buffer == img.buffer
			and other.namespace == img.namespace
			and other.geometry.y == row
		then
			group[#group + 1] = other
		end
	end
	table.sort(group, function(a, b)
		return (a.geometry.x or 0) < (b.geometry.x or 0)
	end)
	return group
end

local function cache_dir()
	local dir = vim.fn.stdpath("cache") .. "/" .. CACHE_SUBDIR
	if vim.fn.isdirectory(dir) == 0 then
		pcall(vim.fn.mkdir, dir, "p")
	end
	return dir
end

local function magick_bin()
	return vim.fn.executable("magick") == 1 and "magick" or "convert"
end

---key 里带上每个源的 mtime/size，源文件改动后自然失效
local function group_key(group)
	local parts = {}
	for _, member in ipairs(group) do
		local path = member.original_path or member.path or ""
		local stat = path ~= "" and vim.uv.fs_stat(path) or nil
		parts[#parts + 1] = ("%s:%d:%d"):format(path, stat and stat.mtime.sec or 0, stat and stat.size or 0)
	end
	return vim.fn.sha256(table.concat(parts, "|")):sub(1, 20)
end

---@param group table[] 已按 x 升序
local function build_composite(group, out_path, on_done)
	local args = { magick_bin() }
	for _, member in ipairs(group) do
		local src = member.original_path or member.path
		args[#args + 1] = "("
		args[#args + 1] = src
		args[#args + 1] = "-resize"
		args[#args + 1] = MAX_SOURCE_WIDTH .. "x>"
		args[#args + 1] = ")"
	end
	local tmp = ("%s.%s.png"):format(out_path, tostring(vim.uv.hrtime()))
	args[#args + 1] = "-background"
	args[#args + 1] = "none"
	-- 两张图宽度不同时居中，避免小图贴左边
	args[#args + 1] = "-gravity"
	args[#args + 1] = "center"
	args[#args + 1] = "-append"
	args[#args + 1] = tmp

	vim.system(args, { text = true }, function(res)
		vim.schedule(function()
			if res.code ~= 0 then
				pcall(vim.fn.delete, tmp)
				on_done(("ImageMagick exited %d: %s"):format(res.code, (res.stderr or ""):gsub("\n.*", "")))
				return
			end
			local ok = pcall(vim.uv.fs_rename, tmp, out_path)
			if not ok then
				pcall(vim.fn.delete, tmp)
				on_done("failed to move the composited image into the cache")
				return
			end
			on_done(nil)
		end)
	end)
end

---合成图（可能异步，未就绪时返回 nil）
---同一批图在不同 buffer / 行里要各自独立，不能共用一个合成图对象
local function composite_key(group, img)
	return ("%s:%d:%d"):format(group_key(group), img.buffer or 0, (img.geometry and img.geometry.y) or 0)
end

local function composite_for(group, img)
	local key = composite_key(group, img)
	local cached = M._composites[key]
	if cached then
		if vim.api.nvim_win_is_valid(cached.window) and cached.window == img.window and cached.buffer == img.buffer then
			return cached
		end
		M._composites[key] = nil
	end

	local path = cache_dir() .. "/" .. key .. ".png"
	if vim.uv.fs_stat(path) then
		local ok, composite = pcall(require("image").from_file, path, {
			-- 独立 namespace：document.render 只会 clear 自己 namespace 下对不上的图，
			-- 否则合成图会在每次重排时被当作「已不存在的匹配」清掉
			id = ("%s-stack"):format(tostring(group[1].id)),
			namespace = ("%s-stack"):format(tostring(group[1].namespace or "image.nvim")),
			window = img.window,
			buffer = img.buffer,
			with_virtual_padding = true,
			inline = true,
		})
		if ok and composite then
			M._composites[key] = composite
			return composite
		end
		return nil
	end

	if not M._building[key] then
		M._building[key] = true
		build_composite(group, path, function(err)
			M._building[key] = nil
			if err then
				vim.notify(("buffer-preview fix: %s"):format(err), vim.log.levels.WARN)
			end
		end)
	end
	return nil
end

---图组变回单张（或成员变了）时，清掉遗留的合成图
local function clear_composites(img, keep_key)
	for key, composite in pairs(M._composites) do
		if key ~= keep_key and composite.buffer == img.buffer and composite.window == img.window then
			pcall(composite.clear, composite)
			-- 关键：只 clear 只是撤掉后端画面，renderer.render() 仍会把它从
			-- global_state.images 里捡回来重画，所以必须一并注销
			composite.global_state.images[composite.id] = nil
			M._composites[key] = nil
		end
	end
end

local function patch_image(img)
	if img._bp_stack_patched then
		return
	end
	img._bp_stack_patched = true

	local orig_render = img.render
	img.render = function(self, geometry)
		trace("enter %s cand=%s", vim.fn.fnamemodify(self.path or "?", ":t"), tostring(is_stack_candidate(self)))
		if not is_stack_candidate(self) then
			return orig_render(self, geometry)
		end

		-- 与 Image:render 一致：先合并 geometry，延后渲染时才能拿回锚点
		if geometry then
			self.geometry = vim.tbl_deep_extend("force", self.geometry or {}, geometry)
		end

		local row = self.geometry and self.geometry.y
		if not row then
			return orig_render(self, geometry)
		end

		local group = group_of(self, row)
		trace(
			"render %s row=%s col=%s group=%d",
			vim.fn.fnamemodify(self.path or "?", ":t"),
			tostring(row),
			tostring(self.geometry and self.geometry.x),
			#group
		)
		if #group < 2 then
			clear_composites(self, nil)
			return orig_render(self, geometry)
		end

		-- renderer.render() 才把图登记进 state.images；非首张成员我们不会走原 render，
		-- 必须自己登记，否则后面的 group_of() 看不到它，永远凑不成一组
		self.global_state.images[self.id] = self

		local leader = group[1]
		local col = leader.geometry.x or 0

		if self ~= leader then
			-- 非首张成员完全不画：整组只由一张合成图代表
			if not M._composites[composite_key(group, self)] and not leader._bp_stack_scheduled then
				leader._bp_stack_scheduled = true
				vim.defer_fn(function()
					leader._bp_stack_scheduled = false
					if vim.api.nvim_buf_is_valid(leader.buffer or 0) then
						leader:render()
					end
				end, 20)
			end
			return false
		end

		local composite = composite_for(group, self)
		trace("  leader composite=%s key=%s", tostring(composite ~= nil), composite_key(group, self))
		if not composite then
			local tries = (self._bp_stack_retries or 0) + 1
			self._bp_stack_retries = tries
			if tries <= BUILD_RETRY_LIMIT then
				vim.defer_fn(function()
					self:render()
				end, 40)
			else
				self._bp_stack_retries = 0
				-- 拼图失败就退回单张渲染，至少能看见第一张
				return orig_render(self, geometry)
			end
			return false
		end

		self._bp_stack_retries = 0
		-- 这张图之前若单独画过，先把旧的后端画面撤掉，避免和合成图同时可见
		if self.is_rendered then
			self.global_state.backend.clear(self.id, true)
			self.is_rendered = false
		end
		composite:render({ x = col, y = row })
		return false
	end
end

local function wrap_api(api)
	local wrapped = setmetatable({}, { __index = api })

	wrapped.from_file = function(path, opts)
		local img = api.from_file(path, opts)
		if img and opts and opts.with_virtual_padding then
			patch_image(img)
		end
		return img
	end

	wrapped.from_url = function(url, opts, callback)
		return api.from_url(url, opts, function(img)
			if img and opts and opts.with_virtual_padding then
				patch_image(img)
			end
			callback(img)
		end)
	end

	return wrapped
end

function M.install()
	if M._installed then
		return
	end
	M._installed = true

	local document = require("image/utils/document")
	local create = document.create_document_integration
	document.create_document_integration = function(config)
		local integration = create(config)
		local setup = integration.setup
		integration.setup = function(api, options, state)
			return setup(wrap_api(api), options, state)
		end
		return integration
	end
end

return M
