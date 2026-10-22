-- https://github.com/nvim-treesitter/nvim-treesitter-textobjects/tree/main
--
-- 约定：
--   aX / iX  = 外层 / 内层 textobject
--   ]X / [X  = 下一个 / 上一个开头
--   ]X 大写  = 下一个 / 上一个结尾
--
-- 尽量避开内置/插件常用键位；条件沿用旧配置的 ]i/[i（会覆盖内置标识符搜索）。
-- Rust / Go / Python / Lua / C 都覆盖；没有对应查询的语言里调用会安静地不动作。
return {
	"nvim-treesitter/nvim-treesitter-textobjects",
	branch = "main",
	init = function()
		-- 关闭内置 ftplugin 的 mappings（Python/Rust/Go 等自带 [[ ]] 等映射），
		-- 避免和下面的 treesitter 映射互相覆盖。
		vim.g.no_plugin_maps = true
	end,
	config = function()
		require("nvim-treesitter-textobjects").setup({
			move = {
				set_jumps = true,
			},
			select = {
				lookahead = true,
				-- 外层对象按整行选，内层默认按字符选。
				selection_modes = {
					["@function.outer"] = "V",
					["@class.outer"] = "V",
					["@conditional.outer"] = "V",
					["@loop.outer"] = "V",
					["@block.outer"] = "V",
					["@comment.outer"] = "V",
				},
				include_surrounding_whitespace = false,
			},
		})

		local select = require("nvim-treesitter-textobjects.select")
		local move = require("nvim-treesitter-textobjects.move")

		local function select_object(query)
			return function()
				-- 没有 parser 的 buffer 保持安静，不打断普通编辑。
				if not pcall(vim.treesitter.get_parser, 0) then
					return
				end
				pcall(select.select_textobject, query, "textobjects")
			end
		end

		local function map_select(key, query, desc)
			vim.keymap.set({ "x", "o" }, "a" .. key, select_object(query .. ".outer"), {
				silent = true,
				desc = "选择外层" .. desc,
			})
			vim.keymap.set({ "x", "o" }, "i" .. key, select_object(query .. ".inner"), {
				silent = true,
				desc = "选择内层" .. desc,
			})
		end

		-- 选择：aX / iX
		map_select("f", "@function", "函数")
		map_select("c", "@class", "类/类型")
		map_select("a", "@parameter", "参数")
		map_select("l", "@loop", "循环")
		map_select("i", "@conditional", "条件")
		map_select("C", "@call", "调用")
		map_select("K", "@block", "语法块")
		map_select("A", "@assignment", "赋值")
		map_select("R", "@return", "返回")

		local function map_move(key, query, desc)
			local function do_move(fn)
				if not pcall(vim.treesitter.get_parser, 0) then
					return
				end
				pcall(fn, query, "textobjects")
			end

			vim.keymap.set({ "n", "x", "o" }, "]" .. key, function()
				do_move(move.goto_next_start)
			end, { silent = true, desc = "下一个" .. desc .. "开头" })

			vim.keymap.set({ "n", "x", "o" }, "[" .. key, function()
				do_move(move.goto_previous_start)
			end, { silent = true, desc = "上一个" .. desc .. "开头" })

			local upper = key:upper()
			if upper == key then
				return
			end

			vim.keymap.set({ "n", "x", "o" }, "]" .. upper, function()
				do_move(move.goto_next_end)
			end, { silent = true, desc = "下一个" .. desc .. "结尾" })

			vim.keymap.set({ "n", "x", "o" }, "[" .. upper, function()
				do_move(move.goto_previous_end)
			end, { silent = true, desc = "上一个" .. desc .. "结尾" })
		end

		-- 移动：]X / [X 开头，]X 大写 / [X 大写 结尾
		-- 避开内置 ]a/]l/]t（参数/位置列表/标签）、]c（gitsigns）、]d（诊断）、
		-- ]b（bufferline）、]m（Rust 宏展开）、]T（neotest）等。
		map_move("f", "@function.outer", "函数")
		map_move("o", "@loop.outer", "循环")
		map_move("i", "@conditional.outer", "条件")
		map_move("k", "@block.outer", "语法块")

		-- 参数交换：适合改 Rust/Go/Python/Lua/C 的函数实参顺序。
		local function swap_parameter(fn)
			if not pcall(vim.treesitter.get_parser, 0) then
				return
			end
			local swap = require("nvim-treesitter-textobjects.swap")
			pcall(swap[fn], "@parameter.inner")
		end

		vim.keymap.set("n", "<A-=>", function()
			swap_parameter("swap_next")
		end, { silent = true, desc = "交换下一个参数" })
		vim.keymap.set("n", "<A-->", function()
			swap_parameter("swap_previous")
		end, { silent = true, desc = "交换上一个参数" })

		-- 兼容旧习惯：]o 仍然跳循环；]i 仍然跳条件。
	end,
}
