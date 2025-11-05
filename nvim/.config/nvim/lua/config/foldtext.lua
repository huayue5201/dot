-- =====================================
-- 高亮定义（不变）
-- =====================================
vim.api.nvim_set_hl(0, "FoldtextDiagERROR", { fg = "#db4b4b" })
vim.api.nvim_set_hl(0, "FoldtextDiagWARN", { fg = "#e0af68" })
vim.api.nvim_set_hl(0, "FoldtextDiagINFO", { fg = "#0db9d7" })
vim.api.nvim_set_hl(0, "FoldtextDiagHINT", { fg = "#10b981" })

local Foldtext = {}

-- =====================================
-- ⚙️ 诊断缓存机制
-- =====================================
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

-- =====================================
-- 🧮 从缓存中快速统计折叠内诊断
-- =====================================
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

-- =====================================
-- 🧱 安全封装 Treesitter capture
-- =====================================
local function safe_get_captures(lnum, col)
	local ok, caps = pcall(vim.treesitter.get_captures_at_pos, 0, lnum, col)
	if not ok or not caps or #caps == 0 then
		return nil
	end
	return caps[1]
end

-- =====================================
-- 辅助函数（改动仅在 build_virt_text）
-- =====================================
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

-- =====================================
-- 🪶 构建折叠行（新增边界检查）
-- =====================================
function Foldtext.custom_foldtext()
	local start, stop = vim.v.foldstart - 1, vim.v.foldend - 1
	if start < 0 or stop < 0 then
		return { { "Invalid fold", "Error" } }
	end

	local line = vim.fn.getline(vim.v.foldstart)
	if not line or line == "" then
		return { { "…", "Comment" } }
	end

	local virt = build_virt_text(expand_tabs(line), start)
	table.insert(virt, { "   ", "Delimiter" })

	local diag, diaghl = fold_diagnostics(start, stop)
	if diag ~= "" then
		table.insert(virt, { diag, diaghl })
	end

	local suffix = ("%dL"):format(stop - start + 1)
	table.insert(virt, { suffix, "FoldColumn" })

	return virt
end

-- =====================================
-- 🧷 自动保存/恢复视图（不变）
-- =====================================
local function remember(mode)
	local ignored = { "DressingSelect", "DressingInput", "gitcommit", "replacer", "help", "qf" }
	if vim.bo.buftype ~= "" or not vim.bo.modifiable or vim.tbl_contains(ignored, vim.bo.filetype) then
		return
	end
	pcall(vim.cmd[mode == "save" and "mkview" or "loadview"], 1)
end

vim.api.nvim_create_autocmd("BufWinLeave", {
	pattern = "?*",
	callback = function()
		remember("save")
	end,
})
vim.api.nvim_create_autocmd("BufWinEnter", {
	pattern = "?*",
	callback = function()
		remember("load")
	end,
})

-- =====================================
-- 🔍 搜索时暂停折叠（不变）
-- =====================================
vim.opt.foldopen:remove({ "search" })
vim.keymap.set("n", "/", "zn/", { desc = "Search & Pause Folds" })

vim.on_key(function(char)
	local key = vim.fn.keytrans(char)
	local search_keys = { "/", "?", "n", "N", "*", "#" }
	local is_search = (key == "<CR>" and vim.fn.getcmdtype():find("[/?]")) or vim.tbl_contains(search_keys, key)
	if vim.fn.mode() ~= "n" and not is_search then
		return
	end
	local enable = vim.wo.foldenable
	if is_search and enable then
		vim.opt.foldenable = false
	elseif not is_search and not enable then
		vim.opt.foldenable = true
		vim.cmd.normal("zv")
	end
end, vim.api.nvim_create_namespace("auto_pause_folds"))

return Foldtext
