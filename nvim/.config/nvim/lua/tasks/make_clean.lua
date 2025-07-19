-- lua/tasks/build.lua

return {
	name = "make clean",
	type = "make",
	filetypes = "c",
	make = {
		cmd = "make",
		args = { "clean" },
		-- cwd = "${project_root}/build",
	},
}
