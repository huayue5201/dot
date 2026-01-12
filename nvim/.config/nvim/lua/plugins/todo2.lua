return {
	dir = "~/todo2",
	dependencies = { "nvim-store3" },
	name = "todo2",
	config = function()
		require("todo2").setup()
	end,
}
