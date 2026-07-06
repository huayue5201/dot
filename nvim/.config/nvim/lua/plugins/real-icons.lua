-- https://github.com/Mirsmog/real-icons.nvim

return {
	"Mirsmog/real-icons.nvim",
	build = ":RealIconsInstallPack material",
	opts = {
		pack = "material",
		integrations = {
			neo_tree = true,
			bufferline = true,
		},
	},
}
