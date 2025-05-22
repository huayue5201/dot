vim.api.nvim_set_hl(0, "FoldtextDiagERROR", { fg = "#db4b4b" })
vim.api.nvim_set_hl(0, "FoldtextDiagWARN", { fg = "#e0af68" })
vim.api.nvim_set_hl(0, "FoldtextDiagINFO", { fg = "#0db9d7" })
vim.api.nvim_set_hl(0, "FoldtextDiagHINT", { fg = "#10b981" })

local Foldtext = {}

-- 转换 Tab 为等量空格
local function expand_tabs(line)
	return line:gsub("\t", string.rep(" ", vim.o.tabstop))
end
-- 获取诊断统计信息
local function fold_diagnostics(start_lnum, end_lnum)
	local icons = require("utils.utils").icons.diagnostic
	local counts = { 0, 0, 0, 0 } -- ERROR, WARN, INFO, HINT
	for _, d in ipairs(vim.diagnostic.get(0)) do
		if d.lnum >= start_lnum and d.lnum <= end_lnum then
			counts[d.severity] = counts[d.severity] + 1
		end
	end
	for severity, count in ipairs(counts) do
		if count > 0 then
			local name = ({ "ERROR", "WARN", "INFO", "HINT" })[severity]
			return icons[name] .. count .. " ", "FoldtextDiag" .. name
		end
	end
	return "", ""
end

-- 获取带高亮的折叠行文本
local function build_virt_text(line, lnum, offset)
	local chunks, text, hl = {}, "", "Normal"
	for i = 1, #line do
		local char = line:sub(i, i)
		local cap = vim.treesitter.get_captures_at_pos(0, lnum, (offset or 0) + i - 1)[1]
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

function Foldtext.custom_foldtext()
	local start, stop = vim.v.foldstart - 1, vim.v.foldend - 1
	local virt = build_virt_text(expand_tabs(vim.fn.getline(vim.v.foldstart)), start)
	table.insert(virt, { "   ", "Delimiter" })

	local diag, diaghl = fold_diagnostics(start, stop)
	if diag ~= "" then
		table.insert(virt, { diag, diaghl })
	end

	local suffix = ("%dL"):format(stop - start + 1)
	table.insert(virt, { suffix, "FoldColumn" })

	return virt
end

-- 自动保存/恢复视图
local function remember(mode)
	local ignored = {
		"DressingSelect",
		"DressingInput",
		"gitcommit",
		"replacer",
		"help",
		"qf",
	}
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

-- 搜索时暂停折叠
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
