-- File: nvim/.config/nvim/lua/boot/preflight.lua
---@brief 启动前的环境修补（必须在 LSP / mason 之前执行）

local M = {}

-- LSP 日志轮转
-- Neovim 不轮转 lsp.log。实测已累积 95MB（含大量 "Cannot find request with id"、
-- "duplicate DidOpenTextDocument"），每次写日志都是一次磁盘写入。超过上限就删掉，
-- Neovim 下次写日志会重新创建文件。级别仍保持 ERROR（见 lsp_ext/diagnostics.lua）。
function M.rotate_lsp_log(max_bytes)
	max_bytes = max_bytes or 32 * 1024 * 1024
	local ok, path = pcall(vim.lsp.log.get_filename)
	if not ok or not path then
		return
	end
	local stat = vim.uv.fs_stat(path)
	if stat and stat.size > max_bytes then
		pcall(vim.uv.fs_unlink, path)
	end
end

--- 删除 rustowl 在当前项目留下的 target/owl
--- rustowl 每次分析都会往 target/owl 写整套 cargo check 产物（实测 283M），
--- 而它现在是手动触发，不清理就只会越积越多。超过阈值就整目录删。
--- 放到 defer 里跑，不挡启动：du 统计本身可能要几百毫秒。
---@param limit_mb number|nil 默认 200MB
function M.clean_stale_owl(limit_mb)
	limit_mb = limit_mb or 200
	local root = vim.fs.root(0, { "Cargo.toml" }) or vim.fn.getcwd()
	local dir = vim.fs.joinpath(root, "target", "owl")
	if vim.fn.isdirectory(dir) == 0 then
		return
	end
	local out = vim.fn.system({ "du", "-sk", dir })
	local kb = tonumber(tostring(out):match("^(%d+)"))
	if not kb or kb <= limit_mb * 1024 then
		return
	end
	if vim.fn.delete(dir, "rf") == 0 then
		vim.notify(string.format("清掉 rustowl 产物 %s (%dMB)", dir, math.floor(kb / 1024)), vim.log.levels.INFO)
	end
end

return M
