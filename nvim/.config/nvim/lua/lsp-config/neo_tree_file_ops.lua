---@diagnostic disable: missing-fields, assign-type-mismatch
local M = {}

local TIMEOUT_MS = 1000

---------------------------------------------------------
-- Apply workspace edits returned by LSP
---------------------------------------------------------
local function apply_workspace_edit(response, offset_encoding)
	if type(response) == "string" then
		vim.notify("LSP error: " .. response, vim.log.levels.ERROR)
		return
	end

	if response and response.err then
		vim.notify("LSP error: " .. response.err, vim.log.levels.ERROR)
		return
	end

	if response and response.result then
		local bufs = {}
		local changes = response.result.documentChanges or {}

		for _, doc in ipairs(changes) do
			local uri = doc.textDocument and doc.textDocument.uri
			if uri then
				bufs[#bufs + 1] = vim.uri_to_bufnr(uri)
			end
		end

		vim.lsp.util.apply_workspace_edit(response.result, offset_encoding)

		for _, bufnr in ipairs(bufs) do
			vim.api.nvim_buf_call(bufnr, function()
				vim.cmd("write")
			end)
		end
	end
end

---------------------------------------------------------
-- Register Neo-tree events AFTER Neo-tree loads
---------------------------------------------------------
local function register_neotree_events()
	local ok, events = pcall(require, "neo-tree.events")
	if not ok then
		return
	end

	local lsp = vim.lsp

	-- didRename
	events.subscribe({
		event = events.FILE_MOVED,
		handler = function(args)
			local old = args.source
			local new = args.destination

			for _, client in ipairs(lsp.get_clients()) do
				local cap = client.server_capabilities.workspace
					and client.server_capabilities.workspace.fileOperations
					and client.server_capabilities.workspace.fileOperations.didRename

				if cap then
					client:notify("workspace/didRenameFiles", {
						files = { { oldUri = vim.uri_from_fname(old), newUri = vim.uri_from_fname(new) } },
					})
				end
			end
		end,
	})

	-- willRename
	events.subscribe({
		event = events.BEFORE_FILE_MOVE,
		handler = function(args)
			local old = args.source
			local new = args.destination

			for _, client in ipairs(lsp.get_clients()) do
				local cap = client.server_capabilities.workspace
					and client.server_capabilities.workspace.fileOperations
					and client.server_capabilities.workspace.fileOperations.willRename

				if cap then
					local response = client:request_sync("workspace/willRenameFiles", {
						files = { { oldUri = vim.uri_from_fname(old), newUri = vim.uri_from_fname(new) } },
					}, TIMEOUT_MS)

					apply_workspace_edit(response, client.offset_encoding)
				end
			end
		end,
	})
end

---------------------------------------------------------
-- Auto-register fileOperations capabilities
---------------------------------------------------------
local file_ops = {
	willRename = true,
	didRename = true,
	willCreate = true,
	didCreate = true,
	willDelete = true,
	didDelete = true,
}

function M.setup()
	-- 1. Inject capabilities BEFORE any LSP starts
	local orig_start = vim.lsp.start_client

	vim.lsp.start_client = function(config)
		config.capabilities = config.capabilities or {}
		config.capabilities.workspace = config.capabilities.workspace or {}

		config.capabilities.workspace.fileOperations =
			vim.tbl_deep_extend("force", file_ops, config.capabilities.workspace.fileOperations or {})

		return orig_start(config)
	end

	-- 2. Register Neo-tree events AFTER Neo-tree loads
	vim.api.nvim_create_autocmd("User", {
		pattern = "NeoTreeInit",
		callback = register_neotree_events,
	})
end

return M
