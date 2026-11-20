-- ============================================================================
-- FIX:(image.nvim/markdown-inline-stack)
-- ============================================================================
-- 这是一个「临时修复」，不是插件功能。上游修好后整份删掉即可（含
-- plugins/tools/image.lua 里带 FIX 标记的那一行 require）。
--
-- 问题：markdown 里同一行出现多张图（典型：表格 `| ![a](a.png) | ![b](b.png) |`）
-- 时，image.nvim 的 markdown 集成按 treesitter 节点渲染
--   lua/image/utils/document.lua: render_image -> image:render({ x = start_col, y = start_row })
-- 两张图 start_row 相同（实测 row=4 col=2 / row=4 col=28），于是绝对 y 相同、
-- 整体重叠，只剩上层那张可见；且两张图各自往锚点行插 virt_lines，padding 却是
-- 正确的两倍行数 —— 表现就是「图叠在一起，下面又空出一大块」。
--
-- 修法：不改上游代码，在 config 里包装 document 集成传进来的 api，
-- 对带 virtual padding 的图对象替换 Image:render：
--   1. 同锚点行、x 更小的兄弟图已渲染高度累加 => render_offset_top（下移绘制位置）
--   2. overlap = offset + 1（让 reserved_lines = 自身高度，padding 不重复累加）
--   3. x 偏移大的图按剩余窗口宽度设 max_width_window_percentage，避免右缘裁切
--   4. 首轮兄弟图高度未知时先不画，defer 重试；渲染完跑一次 settle() 把
--      因高度变化而失配的成员重渲染（深度上限 8 防递归）
-- 依据：renderer.lua 的 absolute_y += render_offset_top、get_overlap_scroll_position、
--       image.lua 的 get_reserved_lines(height, offset, overlap)。
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
M._depth = 0
local RETRY_LIMIT = 12

---尺寸/位置只对这些图有意义
---@param img table
local function is_stack_candidate(img)
	return img.buffer ~= nil and img.inline and img.with_virtual_padding and img.geometry ~= nil
end

---同一锚点行、同 buffer 同 namespace 的其它内联图
---@param img table
---@param row integer
local function siblings_of(img, row)
	local out = {}
	for _, other in pairs(img.global_state.images) do
		if is_stack_candidate(other) and other ~= img and other.buffer == img.buffer and other.namespace == img.namespace and other.geometry.y == row then
			out[#out + 1] = other
		end
	end
	return out
end

---@return integer before 需要在自身绘制位置上追加的行数
---@return boolean pending 有更靠左的兄弟图还没渲染出高度
local function measure(img, row, col)
	local before, pending = 0, false
	for _, other in ipairs(siblings_of(img, row)) do
		if (other.geometry.x or 0) < col then
			local h = other.rendered_geometry and other.rendered_geometry.height
			if h then
				before = before + h
			else
				pending = true
			end
		end
	end
	return before, pending
end

---宽度按「窗口剩余列数」压，免得第二列的图被右缘裁掉
local function clamp_width(img, col)
	local win = img.window
	if not win or not vim.api.nvim_win_is_valid(win) then
		return
	end
	local win_width = vim.api.nvim_win_get_width(win)
	local avail = win_width - math.min(col, win_width - 4)
	if avail < 4 then
		return
	end
	img.max_width_window_percentage = math.max(1, math.floor(avail * 100 / win_width))
end

local function apply_layout(img, row, col)
	local before, pending = measure(img, row, col)
	img.render_offset_top = before
	img.overlap = before > 0 and before + 1 or nil
	if before > 0 then
		clamp_width(img, col)
	end
	return pending
end

---首位成员之后的高度变化会让后面成员的 offset 失配，这里只重渲染失配的那些
local function settle(img, row)
	if M._depth > 8 then
		return
	end

	local group = siblings_of(img, row)
	group[#group + 1] = img
	table.sort(group, function(a, b)
		return (a.geometry.x or 0) < (b.geometry.x or 0)
	end)

	local acc, stale = 0, {}
	for _, member in ipairs(group) do
		local want_overlap = acc > 0 and acc + 1 or nil
		if member.render_offset_top ~= acc or member.overlap ~= want_overlap then
			member.render_offset_top = acc
			member.overlap = want_overlap
			stale[#stale + 1] = member
		end
		acc = acc + ((member.rendered_geometry and member.rendered_geometry.height) or 0)
	end

	if #stale == 0 then
		return
	end

	M._depth = M._depth + 1
	for _, member in ipairs(stale) do
		member:render()
	end
	M._depth = M._depth - 1
end

local function patch_image(img)
	if img._bp_stack_patched then
		return
	end
	img._bp_stack_patched = true

	local orig_render = img.render
	img.render = function(self, geometry)
		if not is_stack_candidate(self) then
			return orig_render(self, geometry)
		end

		-- 与 Image:render 一致：先合并 geometry，延后渲染时才能拿回锚点
		if geometry then
			self.geometry = vim.tbl_deep_extend("force", self.geometry or {}, geometry)
		end

		local row = self.geometry and self.geometry.y
		local col = self.geometry and self.geometry.x
		if not row then
			return orig_render(self, geometry)
		end

		-- 首轮：左边的兄弟图还在异步转换，高度未知。先别画，等它出来再画，
		-- 否则会先按 offset 0 画一帧再跳到正确位置。
		if apply_layout(self, row, col) then
			local tries = (self._bp_stack_retries or 0) + 1
			self._bp_stack_retries = tries
			if tries <= RETRY_LIMIT then
				vim.defer_fn(function()
					if self.rendered_geometry and self.rendered_geometry.height then
						return
					end
					self:render()
				end, 25)
			end
			return false
		end

		self._bp_stack_retries = 0
		local ok = orig_render(self, geometry)
		settle(self, row)
		return ok
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
