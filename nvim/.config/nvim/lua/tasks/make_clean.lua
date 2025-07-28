-- lua/tasks/build.lua

return {
	name = "make clean",
	type = "make",
	make = {
	filetypes = "c",
		cmd = "make",
		args = { "clean" },
		-- cwd = "${project_root}/build",
	},
}
