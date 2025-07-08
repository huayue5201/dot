-- tasks/make_example.lua
return {
	name = "Simple Make Task",
	type = "make", -- 对应框架积木名称

	-- 框架专用配置
	make = {
		cmd = "echo",
		args = { "Hello, Make System!" },
	},

	-- 可选依赖
	deps = {},
}
