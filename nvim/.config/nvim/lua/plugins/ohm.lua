-- https://github.com/ryan-WORK/ohm

return {
	"ryan-WORK/ohm",
	build = "./build.sh",
	config = function()
		require("ohm").setup({
			-- Path to ohm binary. Auto-detected from bin/ohm in plugin dir or PATH.
			binary = nil,

			-- Unix socket path for the control channel.
			socket = vim.fn.stdpath("data") .. "/ohm.sock",

			-- Enable verbose daemon logging (useful for debugging LSP issues).
			debug = true,
		})
	end,
}
