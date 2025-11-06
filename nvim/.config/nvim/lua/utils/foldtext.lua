-- =====================================
-- 🌈 Foldtext 模块（诊断缓存 + UFO 虚拟文本）
-- =====================================
local Foldtext = {}

-- ===============================
-- 🎨 高亮定义
-- ===============================
vim.api.nvim_set_hl(0, "FoldtextDiagERROR", { fg = "#db4b4b" })
vim.api.nvim_set_hl(0, "FoldtextDiagWARN", { fg = "#e0af68" })
vim.api.nvim_set_hl(0, "FoldtextDiagINFO", { fg = "#0db9d7" })
vim.api.nvim_set_hl(0, "FoldtextDiagHINT", { fg = "#10b981" })
vim.api.nvim_set_hl(0, "FoldtextDelimiter", { fg = "#737aa2" })
vim.api.nvim_set_hl(0, "FoldtextCount", { fg = "#7aa2f7" })

-- ===============================
-- ⚙️ 诊断缓存
-- ===============================
local diag_cache = {}

vim.api.nvim_create_autocmd("DiagnosticChanged", {
	callback = function(args)
		local buf = args.buf
		local diags = vim.diagnostic.get(buf)
		local cache = {}

		for _, d in ipairs(diags) do
			local l = d.lnum
			local sev = d.severity
			if l and sev then
				cache[l] = cache[l] or { 0, 0, 0, 0 }
				cache[l][sev] = cache[l][sev] + 1
			end
		end

		diag_cache[buf] = cache
	end,
})

-- ===============================
-- 🧮 折叠诊断统计
-- ===============================
local function fold_diagnostics(start_lnum, end_lnum)
	local buf = vim.api.nvim_get_current_buf()
	local cache = diag_cache[buf]
	if not cache then
		return "", ""
	end

	local counts = { 0, 0, 0, 0 }
	for l = start_lnum, end_lnum do
		local c = cache[l]
		if c then
			for i = 1, 4 do
				counts[i] = counts[i] + c[i]
			end
		end
	end

	for severity, count in ipairs(counts) do
		if count > 0 then
			local name = ({ "ERROR", "WARN", "INFO", "HINT" })[severity]
			local icons = require("utils.utils").icons.diagnostic
			return icons[name] .. count .. " ", "FoldtextDiag" .. name
		end
	end
	return "", ""
end

-- ===============================
-- 🌳 Treesitter Capture（安全封装）
-- ===============================
local function safe_get_captures(lnum, col)
	local ok, caps = pcall(vim.treesitter.get_captures_at_pos, 0, lnum, col)
	if ok and caps and #caps > 0 then
		return caps[1]
	end
end

-- ===============================
-- ⚙️ 构造语法高亮虚拟文本
-- ===============================
local function expand_tabs(line)
	return line:gsub("\t", string.rep(" ", vim.o.tabstop))
end

local function build_virt_text(line, lnum, offset)
	local chunks, text, hl = {}, "", "Normal"
	for i = 1, #line do
		local char = line:sub(i, i)
		local cap = safe_get_captures(lnum, (offset or 0) + i - 1)
		local newhl = cap and "@" .. cap.capture or "Normal"
		if newhl ~= hl then
			if #text > 0 then
				table.insert(chunks, { text, hl })
			end
			text, hl = char, newhl
		else
			text = text .. char
		end
	end
	if #text > 0 then
		table.insert(chunks, { text, hl })
	end
	return chunks
end

-- ===============================
-- 🪶 UFO 虚拟文本接口
-- ===============================
function Foldtext.custom_foldtext(virt_text, lnum, endLnum, width, truncate)
	-- 🧩 UFO 会传入 virt_text, lnum, endLnum, width, truncate
	local newVirtText = {}
	local line = vim.fn.getline(lnum)
	if not line or line == "" then
		return { { "…", "Comment" } }
	end

	local start, stop = lnum - 1, endLnum - 1
	local virt = build_virt_text(expand_tabs(line), start)
	table.insert(virt, { "   ", "FoldtextDelimiter" })

	-- 📊 诊断信息
	local diag, diaghl = fold_diagnostics(start, stop)
	if diag ~= "" then
		table.insert(virt, { diag, diaghl })
	end

	-- 📏 折叠行统计
	local folded_lines = stop - start + 1
	table.insert(virt, { string.format("%dL", folded_lines), "FoldtextCount" })

	-- ✂️ 控制显示宽度
	local cur_width = 0
	for _, chunk in ipairs(virt) do
		local text, hl = chunk[1], chunk[2]
		local w = vim.fn.strdisplaywidth(text)
		if cur_width + w < width then
			table.insert(newVirtText, chunk)
			cur_width = cur_width + w
		else
			text = truncate(text, width - cur_width)
			table.insert(newVirtText, { text, hl })
			break
		end
	end

	return newVirtText
end

return Foldtext
