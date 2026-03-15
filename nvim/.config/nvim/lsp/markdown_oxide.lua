local function execute_lsp_command(cmd, args)
	-- 使用 get_active_clients 来避免参数警告
	local clients = vim.lsp.get_active_clients({ bufnr = 0 })
	for _, client in ipairs(clients) do
		-- 检查客户端名称以确保是 markdown-oxide
		if client.name == "markdown-oxide" and client.supports_method("workspace/executeCommand") then
			client:exec_cmd({ command = cmd, arguments = args }, { bufnr = 0 })
		end
	end
end

return {
	cmd = { "markdown-oxide" },
	filetypes = { "markdown" },
	root_markers = {
		".git/",
	},
	single_file_support = true,
	docs = {
		description = [[
https://github.com/Feel-ix-343/markdown-oxide

Editor Agnostic PKM: you bring the text editor and we
bring the PKM.

Inspired by and compatible with Obsidian.

Check the readme to see how to properly setup.
        ]],
	},
	commands = {
		Today = {
			function()
				execute_lsp_command("jump", { "today" })
			end,
			description = "Open today's daily note",
		},
		Tomorrow = {
			function()
				execute_lsp_command("jump", { "tomorrow" })
			end,
			description = "Open tomorrow's daily note",
		},
		Yesterday = {
			function()
				execute_lsp_command("jump", { "yesterday" })
			end,
			description = "Open yesterday's daily note",
		},
	},
}
