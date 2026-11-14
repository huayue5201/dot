-- https://github.com/0xdeadf1sh/AssemblyForNeovim
--
-- 把 C / C++ / Rust 的函数（或选区）编成汇编，在浮窗里看：
--   +/- 调 -O 级别、R 重跑、q 关闭。
-- 依赖：cc / c++、rustc / cargo、c++filt（去修饰名），本机都在 PATH 上；
-- 目录里有 compile_commands.json 时会自动拿它的 -I / -D 参数。
--
-- 为什么不用上游的 setup()：它把键位硬编码成 <leader>a（n 和 x 两个模式），
-- 而本机 <leader>a 是「AI / Agent」分组前缀，直接绑上会把整个分组遮蔽掉。
-- 所以这里不调 setup()，只接管两件事：
--   * :Asm（range 命令，上游 setup 里就是这个定义）
--   * <leader>ra —— 与上游 setup 的 <leader>a 行为完全一致，另按 ft 限定到
--     c / cpp / rust，别让它在 markdown / lua 里变成噪音。
--
-- enclosing_fn 是自己写的：上游把它写成了未导出的局部函数，所以我们按同样的
-- 逻辑（向上找第一个节点类型含 "function"/"method" 的祖先）复刻一份。

---光标所在的函数/方法范围（1-based 闭区间），找不到返回 nil
---@return integer?, integer?
local function enclosing_fn()
	local ok, node = pcall(vim.treesitter.get_node)
	if not ok or not node then
		return nil
	end
	while node do
		local t = node:type()
		if t:match("function") or t:match("method") then
			local sr, _, er = node:range()
			return sr + 1, er + 1
		end
		node = node:parent()
	end
end

---@param l1 integer
---@param l2 integer
local function show(l1, l2)
	require("asm").show(l1, l2)
end

return {
	"0xdeadf1sh/AssemblyForNeovim",
	keys = {
		{
			"<leader>ra",
			function()
				local l1, l2 = enclosing_fn()
				show(l1 or vim.fn.line("."), l2 or vim.fn.line("."))
			end,
			ft = { "c", "cpp", "rust" },
			desc = "[A]ssembly: 光标所在的函数",
		},
		{
			"<leader>ra",
			":Asm<CR>",
			mode = "x",
			ft = { "c", "cpp", "rust" },
			desc = "[A]ssembly: 选区",
		},
	},
	config = function()
		vim.api.nvim_create_user_command("Asm", function(o)
			show(o.line1, o.line2)
		end, { range = true, desc = "查看汇编（选区 / 当前行）" })
	end,
}
