return {
	dir = "~/todo2",
	dependencies = { "nvim-store3" },
	name = "todo2",
	-- TODO:ref:79295a
	config = function()
		require("todo2").setup()
	end,
}
