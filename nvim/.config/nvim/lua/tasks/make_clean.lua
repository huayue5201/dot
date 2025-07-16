-- lua/tasks/build.lua

return {
	name = "make clean",
	type = "make",
	make = {
		cmd = "make",
		args = { "clean" },
		-- cwd = "${project_root}/build",
	},
}
