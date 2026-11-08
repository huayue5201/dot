-- ============================================================================
-- FIX:(neotest-golang#599)
-- ============================================================================
-- 这是一个「临时修复」，不是插件功能。上游修好后整份删掉即可（含 neotest.lua
-- 里带 FIX 标记的一行 require/file 调用）。
--
-- 问题：upstream 的 table_tests_list.scm / table_tests_unkeyed.scm 把
-- 「枚举 literal_value 的 N 个元素」和「同一 pattern 里的 for_statement 尾巴」
-- 放进同一个 query，tree-sitter 需要在组合空间里回溯 → 接近 O(N²)：
--   400 行表驱动文件 6.1s / 2.7s，1000 行 unkeyed 文件 64s。
-- neotest 的 discovery 跑在共用的 `nvim --embed` 子进程里，于是整个 summary 卡死。
-- 另外 adapter 没给 parse_positions 传 match_limit，默认 256，超限会静默丢掉
-- 文件开头那批用例。
--
-- 修法：拆成两个线性 query（声明半段 / 循环半段，各 <3ms），用 Lua 按
-- 「同一函数作用域 + 表变量名 + name 字段名」把两侧关联起来，产出与原实现
-- 逐节点一致的位置树（已在 upstream 全部 24 个 fixtures + 400/1000 行基准上比对）。
--   1000 行文件：41.6s → 19.7ms
--
-- 清理方式（上游修复后）：
--   1. 删除 lua/fix/neotest_golang_table_tests.lua
--   2. 删除 lua/plugins/tools/neotest.lua 里带 FIX(neotest-golang#599) 注释的那一行
-- ============================================================================
local M = {}

-- 守卫元数据：见 lua/fix/init.lua 顶部说明；:FixStatus 查看状态
M.meta = {
	id = "neotest-golang#599",
	title = "Table-driven test discovery is O(N²) (enumerating literal_value + for_statement backtracking blows up in one query)",
	plugin = "neotest-golang",
	issue = "https://github.com/fredrikaverpil/neotest-golang/issues/599",
	baseline_rev = "65b2be6",
	-- 两个「声明 + for 循环」合写在一个 pattern 里的文件；任一仍含 for_statement 就说明没修
	buggy = {
		{ file = "lua/neotest-golang/queries/go/table_tests_list.scm", contains = "(for_statement" },
		{ file = "lua/neotest-golang/queries/go/table_tests_unkeyed.scm", contains = "(for_statement" },
	},
	cleanup = { "Also delete lua/fix/neotest_golang_table_tests.lua and the require in plugins/tools/neotest.lua" },
}

local DECL_LIST = [[
(short_var_declaration
  left: (expression_list
    (identifier) @test.cases)
  right: (expression_list
    (composite_literal
      (literal_value
        (literal_element
          (literal_value
            (keyed_element
              (literal_element
                (identifier) @test.field.name)
              (literal_element
                (interpreted_string_literal) @test.name)))) @test.definition))))
]]

local DECL_UNKEYED = [[
(short_var_declaration
  left: (expression_list
    (identifier) @test.cases)
  right: (expression_list
    (composite_literal
      type: (slice_type
        element: (struct_type
          (field_declaration_list
            .
            (field_declaration
              name: (field_identifier) @test.field.name
              type: (type_identifier) @field.type
              (#eq? @field.type "string")))))
      body: (literal_value
        (literal_element
          (literal_value
            .
            (literal_element
              (interpreted_string_literal) @test.name)
            (literal_element)) @test.definition)))))
]]

local LOOP_LIST = [[
(for_statement
  (range_clause
    left: (expression_list
      (identifier) @test.case)
    right: (identifier) @test.cases1)
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @test.operand
            (#match? @test.operand "^[t]$")
            field: (field_identifier) @test.method
            (#match? @test.method "^Run$"))
          arguments: (argument_list
            (selector_expression
              operand: (identifier) @test.case1
              field: (field_identifier) @test.field.name1)))))))
]]

local LOOP_UNKEYED = [[
(for_statement
  (range_clause
    left: (expression_list
      (identifier) @test.key.name
      (identifier) @test.case)
    right: (identifier) @test.cases1)
  body: (block
    (statement_list
      (expression_statement
        (call_expression
          function: (selector_expression
            operand: (identifier) @test.operand
            (#match? @test.operand "^[t]$")
            field: (field_identifier) @test.method
            (#match? @test.method "^Run$"))
          arguments: (argument_list
            (selector_expression
              operand: (identifier) @test.case1
              field: (field_identifier) @test.field.name1)))))))
]]

local MATCH_LIMIT = 50000

--- 同步读文件（upstream 用 lib.files.read，是 async 的；这里保留原文末换行）
local function read_file(file_path)
	local fh = io.open(file_path, "rb")
	if not fh then
		return require("neotest.lib").files.read(file_path)
	end
	local content = fh:read("*a")
	fh:close()
	return content
end

--- 收集一次 query 的全部 captures
local function run(parsed, root, content)
	local out = {}
	for _, match in parsed:iter_matches(root, content, nil, nil, { match_limit = MATCH_LIMIT }) do
		local caps = {}
		for i, name in ipairs(parsed.captures) do
			local node = match[i]
			caps[name] = type(node) == "table" and node[#node] or node
		end
		out[#out + 1] = caps
	end
	return out
end

local function text(caps, key, content)
	local node = caps[key]
	if not node then
		return nil
	end
	return vim.treesitter.get_node_text(node, content)
end

--- 这些 query 本身是线性的（单文件 <3ms），原样沿用；只有 list/unkeyed 两种
--- 会枚举表元素，才走两遍法。
local function cheap_query()
	local q = require("neotest-golang.query")
	return table.concat({
		q.test_function,
		q.table_tests_loop,
		q.table_tests_map,
		q.table_tests_inline_field_access,
		q.table_tests_loop_unkeyed,
	})
end

--- 与 neotest.lib.treesitter.collect 等价，但只取线性的那部分 query
local function base_positions(file_path, root, content, lang)
	local lib = require("neotest.lib")
	local parsed = lib.treesitter.normalise_query(lang, cheap_query())
	local positions = {}
	for _, caps in ipairs(run(parsed, root, content)) do
		local kind = caps["test.name"] and "test" or (caps["namespace.name"] and "namespace" or nil)
		if kind then
			local definition = caps[kind .. ".definition"]
			positions[#positions + 1] = {
				type = kind,
				path = file_path,
				name = vim.treesitter.get_node_text(caps[kind .. ".name"], content),
				range = { definition:range() },
			}
		end
	end
	return positions
end

--- 向上找到最近的函数节点（表声明和 consuming 的 for 必须在同一函数里）
local function scope_of(node)
	local cur = node:parent()
	while cur do
		local kind = cur:type()
		if kind == "function_declaration" or kind == "method_declaration" or kind == "func_literal" then
			return select(1, cur:range())
		end
		cur = cur:parent()
	end
	return 0
end

--- 哪些 (函数, 表变量, name 字段) 真的被 `for … range 表` + `t.Run(x.field)` 消费
local function consumed_tables(root, content, lang)
	local lib = require("neotest.lib")
	local seen = {}
	for _, q in ipairs({ LOOP_LIST, LOOP_UNKEYED }) do
		local parsed = lib.treesitter.normalise_query(lang, q)
		for _, caps in ipairs(run(parsed, root, content)) do
			local var = text(caps, "test.cases1", content)
			local field = text(caps, "test.field.name1", content)
			if
				var
				and field
				and text(caps, "test.operand", content) == "t"
				and text(caps, "test.method", content) == "Run"
			then
				seen[scope_of(caps["test.case1"] or caps["test.cases1"]) .. "::" .. var .. "::" .. field] = true
			end
		end
	end
	return seen
end

--- 表驱动测试行（每个 case 一条位置，range = 该行 literal_value）
local function table_rows(file_path, root, content, lang, seen)
	local lib = require("neotest.lib")
	local rows = {}
	for _, q in ipairs({ DECL_LIST, DECL_UNKEYED }) do
		local parsed = lib.treesitter.normalise_query(lang, q)
		for _, caps in ipairs(run(parsed, root, content)) do
			local var = text(caps, "test.cases", content)
			local field = text(caps, "test.field.name", content)
			local name = text(caps, "test.name", content)
			if var and field and name and seen[scope_of(caps["test.definition"]) .. "::" .. var .. "::" .. field] then
				rows[#rows + 1] = {
					type = "test",
					path = file_path,
					name = name,
					range = { caps["test.definition"]:range() },
				}
			end
		end
	end
	return rows
end

--- 替代 upstream 的 discover_positions
--- @param file_path string
--- @return table neotest.Tree
function M.discover_positions(file_path)
	local lib = require("neotest.lib")
	local content = read_file(file_path)
	local root, lang = lib.treesitter.get_parse_root(file_path, content, {})

	local path_elems = vim.split(file_path, lib.files.sep, { plain = true })
	local positions = {
		{ type = "file", path = file_path, name = path_elems[#path_elems], range = { root:range() } },
	}
	vim.list_extend(positions, base_positions(file_path, root, content, lang))
	vim.list_extend(positions, table_rows(file_path, root, content, lang, consumed_tables(root, content, lang)))

	table.sort(positions, function(a, b)
		if a.range[1] ~= b.range[1] then
			return a.range[1] < b.range[1]
		end
		return a.range[2] < b.range[2]
	end)

	return lib.positions.parse_tree(positions, { nested_tests = true })
end

--- 给 neotest-golang adapter 打补丁（幂等）
function M.install()
	local ok, adapter = pcall(require, "neotest-golang")
	if not ok then
		return
	end
	if adapter.__fast_discovery then
		return
	end
	local upstream = adapter.discover_positions
	adapter.discover_positions = function(file_path)
		local good, tree = pcall(M.discover_positions, file_path)
		if good then
			return tree
		end
		vim.notify(
			("neotest-golang: fast discovery failed, falling back to upstream (%s)"):format(tree),
			vim.log.levels.WARN
		)
		return upstream(file_path)
	end
	adapter.__fast_discovery = true
end

return M
