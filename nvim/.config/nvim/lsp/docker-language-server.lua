-- https://github.com/docker/docker-language-server
---@brief Dockerfile / Compose 的 LSP（brew install docker-language-server）
--- 能力：补全、hover、跳转（多阶段构建的 FROM 别名）、诊断（未知指令/参数、
---   镜像 tag 检查）、文档符号、格式化（走 BuildKit 的 dockerfile formatter）。
--- 只挂 dockerfile。Compose 文件（yaml）在 after/ftplugin/yaml.lua 里按文件名
--- 手动 attach（按 filetype 挂会把 server 拖给所有 yaml buffer）。
--- 所有 yaml buffer；真要接，得在 FileType yaml 里按文件名（docker-compose.yml /
--- compose.yml）调 vim.lsp.start 手动 attach。
return {
	cmd = { "docker-language-server", "start", "--stdio" },
	filetypes = { "dockerfile" },
	root_markers = {
		"Dockerfile",
		"docker-compose.yml",
		"compose.yml",
		"compose.yaml",
		".git",
	},
	single_file_support = true,
	-- server 是按 LSP 的 languageId 分派文档类型的（dockerfile / dockercompose / hcl），
	-- 而 nvim 里 Compose 的 ft 是 yaml，必须显式映射，否则会被当成 Dockerfile 解析
	-- （症状：docker-compose.yml 报 "unknown instruction: services:"）。
	get_language_id = function(_, filetype)
		return filetype == "dockerfile" and "dockerfile" or "dockercompose"
	end,
}
