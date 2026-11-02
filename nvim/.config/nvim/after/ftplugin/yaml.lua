-- Compose 文件的 ft 就是 yaml，按 filetype 挂 docker-language-server 会让它接管
-- 所有 yaml buffer，所以这里只在文件名命中 compose 时才手动 attach。
-- （Dockerfile 走正常的 lsp/docker-language-server.lua，由 FileType 自动启用。）
local base = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ":t"):lower()
local is_compose = base:match("^docker%-compose") ~= nil
	or base == "compose.yaml"
	or base == "compose.yml"
	or base:match("^compose%.[%w]+%.ya?ml$") ~= nil
if not is_compose then
	return
end

local name = "docker-language-server"
if not require("lsp_ext.servers").is_enabled(name) then
	return
end
if #vim.lsp.get_clients({ bufnr = 0, name = name }) > 0 then
	return
end

local cfg = vim.lsp.config[name]
if type(cfg) ~= "table" then
	return
end
-- _root_markers 必须带上：否则 reuse_client 匹配不到已由 vim.lsp.enable 启动的同类 client
vim.lsp.start(cfg, { bufnr = 0, _root_markers = cfg.root_markers })
