-- https://github.com/cordx56/rustowl

return {
	"cordx56/rustowl",
	version = "*", -- Latest stable version
	-- build = "cargo install rustowl",
	lazy = false, -- This plugin is already lazy
	opts = {
		auto_enable = true,
		idle_time = 300,
		highlight_style = "underline",
		colors = {
			lifetime = "#50fa7b", -- Dracula green
			imm_borrow = "#8be9fd", -- Dracula cyan
			mut_borrow = "#ff79c6", -- Dracula pink
			move = "#f1fa8c", -- Dracula yellow
			call = "#ffb86c", -- Dracula orange
			outlive = "#ff5555", -- Dracula red
		},
	},
}
