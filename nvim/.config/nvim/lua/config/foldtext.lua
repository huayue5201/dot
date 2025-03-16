local Foldtext = {}

-- **转换 Tab 为等量空格，保持缩进对齐**
local function replace_tabs_with_spaces(line)
	local col = 0
	return line:gsub("\t", function()
		local spaces = vim.o.tabstop - (col % vim.o.tabstop)
		col = col + spaces
		return (" "):rep(spaces)
	end)
end

-- **获取折叠范围内的 LSP 诊断信息**
local function get_fold_diagnostics(start_lnum, end_lnum)
	local diagnostics = vim.diagnostic.get(0)
	local counts = { 0, 0, 0, 0 } -- { ERROR, WARN, HINT, INFO }
	local severity_map = { "ERROR", "WARN", "HINT", "INFO" }
	local icons = require("config.utils").icons.diagnostic or {}
	for _, diag in ipairs(diagnostics) do
		if diag.lnum >= start_lnum and diag.lnum <= end_lnum then
			counts[diag.severity] = counts[diag.severity] + 1
		end
	end
	for severity, count in ipairs(counts) do
		if count > 0 then
			return string.format("%s%d ", icons[severity_map[severity]], count),
				"DiagnosticSign" .. severity_map[severity]
		end
	end
	return "", ""
end

-- **处理折叠的虚拟文本，保持语法高亮**
local function fold_virt_text(result, s, lnum, coloff)
	local text, hl = "", "Normal"
	coloff = coloff or 0
	for i = 1, #s do
		local char = s:sub(i, i)
		local hls = vim.treesitter.get_captures_at_pos(0, lnum, coloff + i - 1)
		local new_hl = "@" .. (hls[1] and hls[1].capture or "Normal")
		if new_hl ~= hl then
			if #text > 0 then
				table.insert(result, { text, hl })
			end
			text, hl = char, new_hl
		else
			text = text .. char
		end
	end
	if #text > 0 then
		table.insert(result, { text, hl })
	end
end

-- **最终折叠文本拼接**
function Foldtext.custom_foldtext()
	local start_lnum, end_lnum = vim.v.foldstart - 1, vim.v.foldend - 1
	local result = {}
	fold_virt_text(result, replace_tabs_with_spaces(vim.fn.getline(vim.v.foldstart)), start_lnum)
	table.insert(result, { "  ", "Delimiter" })
	local diag_text, diag_hl = get_fold_diagnostics(start_lnum, end_lnum)
	if diag_text ~= "" then
		table.insert(result, { diag_text, diag_hl })
	end
	table.insert(result, { string.format("  %dline", vim.v.foldend - vim.v.foldstart + 1), "Delimiter" })
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
		pcall(function()
			vim.cmd.loadview(1)
		end)
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
	local searchConfirmed = (key == "<CR>" and vim.fn.getcmdtype():find("[/?]") ~= nil)
	if not (searchConfirmed or vim.fn.mode() == "n") then
		return
	end

	local searchKeyUsed = searchConfirmed or vim.tbl_contains(searchKeys, key)
	local pauseFold = vim.opt.foldenable:get() and searchKeyUsed
	local unpauseFold = not vim.opt.foldenable:get() and not searchKeyUsed

	if pauseFold then
		vim.opt.foldenable = false
	elseif unpauseFold then
		vim.opt.foldenable = true
		vim.cmd.normal("zv")
	end
end, vim.api.nvim_create_namespace("auto_pause_folds"))

return Foldtext
