-- https://github.com/chentoast/marks.nvim

return {
	"chentoast/marks.nvim",
	event = "BufReadPost",
	config = function()
		require("marks").setup({
			-- whether to map keybinds or not. default true
			default_mappings = true,
			-- which builtin marks to show. default {}
			-- builtin_marks = { "<", ">", "^" },
			-- whether movements cycle back to the beginning/end of buffer. default true
			cyclic = true,
			-- whether the shada file is updated after modifying uppercase marks. default false
			force_write_shada = false,
			-- how often (in ms) to redraw signs/recompute mark positions.
			-- higher values will have better performance but may cause visual lag,
			-- while lower values may cause performance penalties. default 150.
			refresh_interval = 250,
			-- sign priorities for each type of mark - builtin marks, uppercase marks, lowercase
			-- marks, and bookmarks.
			-- can be either a table with all/none of the keys, or a single number, in which case
			-- the priority applies to all marks.
			-- default 10.
			sign_priority = { lower = 10, upper = 15, builtin = 8, bookmark = 20 },
			-- disables mark tracking for specific filetypes. default {}
			excluded_filetypes = {},
			-- disables mark tracking for specific buftypes. default {}
			excluded_buftypes = {},
			-- marks.nvim allows you to configure up to 10 bookmark groups, each with its own
			-- sign/virttext. Bookmarks can be used to group together positions and quickly move
			-- across multiple buffers. default sign is '!@#$%^&*()' (from 0 to 9), and
			-- default virt_text is "".
			bookmark_0 = {
				sign = "⚑",
				virt_text = "hello world",
				-- explicitly prompt for a virtual line annotation when setting a bookmark from this group.
				-- defaults to false.
				annotate = false,
			},
			mappings = {},
		})

		-- mx    设置书签 x
		-- m,    设置下一个可用的小写字母书签
		-- m;    切换当前行的下一个可用书签
		-- dmx   删除书签 x
		-- dm-   删除当前行上的所有书签
		-- dm<space> 删除当前缓冲区中的所有书签
		-- m] 跳转到下一个书签
		-- m[ 跳转到上一个书签
		-- m: 预览书签。此命令会提示你输入一个特定的书签来预览；按 <cr> 以预览下一个书签。
		-- m[0-9] 从书签组 [0-9] 中添加书签。
		-- dm[0-9] 删除书签组 [0-9] 中的所有书签。
		-- m} 跳转到与光标下书签相同类型的下一个书签。支持跨缓冲区跳转。
		-- m{ 跳转到与光标下书签相同类型的上一个书签。支持跨缓冲区跳转。
		-- dm= 删除光标下的书签。
	end,
}
