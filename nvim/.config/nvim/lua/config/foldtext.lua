local Foldtext = {}

-- **转换 Tab 为等量空格，保持缩进对齐**
local function replace_tabs_with_spaces(line)
	return line:gsub("\t", (" "):rep(vim.o.tabstop))
end

-- **获取折叠范围内的 LSP 诊断信息**
local function get_fold_diagnostics(start_lnum, end_lnum)
	local diagnostics = vim.diagnostic.get(0) or {} -- 避免 diagnostics 为空
	local counts = { 0, 0, 0, 0 } -- { ERROR, WARN, HINT, INFO }
	local severity_map = { "ERROR", "WARN", "HINT", "INFO" }

	-- 确保 icons 不是 nil
	local ok, utils = pcall(require, "config.utils")
	local icons = (ok and utils.icons and utils.icons.diagnostic) or {}

	for _, diag in ipairs(diagnostics) do
		local severity = diag.severity or vim.diagnostic.severity.INFO -- 避免 nil
		if diag.lnum and diag.lnum >= start_lnum and diag.lnum <= end_lnum then
			counts[severity] = (counts[severity] or 0) + 1 -- 避免 nil 计算错误
		end
	end

	for severity, count in ipairs(counts) do
		if count > 0 then
			return (icons[severity_map[severity]] or "") .. count .. " ", "DiagnosticSign" .. severity_map[severity]
		end
	end
	return "", ""
end

-- **处理折叠的虚拟文本，保持语法高亮**
local function fold_virt_text(result, s, lnum, coloff)
	local text, hl, i = "", "Normal", 0
	coloff = coloff or 0

	while i < #s do
		i = i + 1
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local new_hl = "@" .. (hls[1] and hls[1].capture or "Normal")

		if new_hl ~= hl then
			if #text > 0 then
				result[#result + 1] = { text, hl }
			end
			text, hl = char, new_hl
		else
			text = text .. char
		end
	end

	if #text > 0 then
		result[#result + 1] = { text, hl }
	end
end

-- **最终折叠文本拼接**
function Foldtext.custom_foldtext()
	local start_lnum, end_lnum = vim.v.foldstart - 1, vim.v.foldend - 1
	local result = {}

	fold_virt_text(result, replace_tabs_with_spaces(vim.fn.getline(vim.v.foldstart)), start_lnum)
	result[#result + 1] = { "  ", "Delimiter" }

	local diag_text, diag_hl = get_fold_diagnostics(start_lnum, end_lnum)
	if diag_text ~= "" then
		result[#result + 1] = { diag_text, diag_hl }
	end

	result[#result + 1] = { string.format("  %dline", end_lnum - start_lnum + 1), "Delimiter" }
	return result
end

-- **记住窗口视图（view）**
local function remember(mode)
	local ignoredFts = {
		"TelescopePrompt",
		"DressingSelect",
		"DressingInput",
		"toggleterm",
		"gitcommit",
		"replacer",
		"harpoon",
		"help",
		"qf",
	}
	if vim.tbl_contains(ignoredFts, vim.bo.filetype) or vim.bo.buftype ~= "" or not vim.bo.modifiable then
		return
	end

	if mode == "save" then
		vim.cmd.mkview(1)
	else
		local ok = pcall(vim.cmd.loadview, 1)
		if not ok then
			return
		end
	end
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

-- **优化搜索折叠**
vim.opt.foldopen:remove({ "search" })
vim.keymap.set("n", "/", "zn/", { desc = "Search & Pause Folds" })

vim.on_key(function(char)
	local key = vim.fn.keytrans(char)
	local searchKeys = { "n", "N", "*", "#", "/", "?" }
	local is_search = (key == "<CR>" and vim.fn.getcmdtype():find("[/?]")) or vim.tbl_contains(searchKeys, key)

	if vim.fn.mode() ~= "n" and not is_search then
		return
	end

	local fold_enabled = vim.wo.foldenable
	if is_search and fold_enabled then
		vim.opt.foldenable = false
	elseif not is_search and not fold_enabled then
		vim.opt.foldenable = true
		vim.cmd.normal("zv")
	end
end, vim.api.nvim_create_namespace("auto_pause_folds"))

return Foldtext
