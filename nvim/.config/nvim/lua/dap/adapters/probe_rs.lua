-- https://probe.rs/

return {
	setup = function(dap)
		dap.adapters["probe-rs-debug"] = {
			type = "server",
			port = "${port}",
			executable = {
				command = "probe-rs",
				args = { "dap-server", "--port", "${port}" },
			},
		}
		require("dap.ext.vscode").type_to_filetypes["probe-rs-debug"] = { "rust" }
	end,
}
