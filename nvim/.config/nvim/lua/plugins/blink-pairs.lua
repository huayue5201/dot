-- https://github.com/saghen/blink.pairs

return {
	"saghen/blink.pairs",
	version = "*", -- (recommended) only required with prebuilt binaries
	event = "InsertEnter",
	-- OR build from source
	build = "cargo build --release",
	--- @module 'blink.pairs'
	--- @type blink.pairs.Config
	opts = {
		mappings = {
			-- you can call require("blink.pairs.mappings").enable() and require("blink.pairs.mappings").disable() to enable/disable mappings at runtime
			enabled = true,
			-- see the defaults: https://github.com/Saghen/blink.pairs/blob/main/lua/blink/pairs/config/mappings.lua#L10
			pairs = {},
		},
		highlights = {
			enabled = true,
			groups = {
				"BlinkPairsOrange",
				"BlinkPairsPurple",
				"BlinkPairsBlue",
			},
			matchparen = {
				enabled = true,
				group = "MatchParen",
			},
		},
		debug = false,
	},
}
