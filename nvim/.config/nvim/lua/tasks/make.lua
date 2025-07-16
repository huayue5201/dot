-- lua/tasks/build.lua

return {
	name = "make",
	type = "make",
	-- filetypes = "c",
	make = {
		cmd = "make",
		args = { "all" },
		-- cwd = "${project_root}/build",
	},
}
