--- @module 'blink.cmp'
--- @class blink.cmp.Source
local source = {}

-- 这个函数会在 blink.cmp 加载你的源时被调用
-- opts 来自稍后配置中的 sources.providers.cargo.opts
function source.new(opts)
	local self = setmetatable({}, { __index = source })
	self.opts = opts
	return self
end

-- (可选) 控制该源在哪些上下文中启用。例如，只在终端模式启用
-- function source:enabled()
--   return vim.bo.buftype == 'terminal'
-- end

-- (可选) 定义哪些非字母数字字符会触发补全，比如 '.' 或 ':'。
-- function source:get_trigger_characters()
--   return { ' ' }  -- 例如，在输入空格后触发
-- end

-- 这是最核心的函数，负责生成补全项
---@param ctx blink.cmp.Context
---@param callback fun(response: blink.cmp.CompletionResponse)
function source:get_completions(ctx, callback)
	-- 1. 获取当前输入的内容，用于过滤补全项
	-- local line = ctx.line
	-- local cursor_col = ctx.cursor[2]
	-- local input = line:sub(1, cursor_col)

	-- 2. 在这里获取 cargo 命令列表（可以是静态列表，也可以是动态生成）
	--    下面的示例是硬编码的几个常见命令
	local cargo_commands = {
		{ label = "build", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		{ label = "run", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		{ label = "test", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		{ label = "check", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		{ label = "add", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		{ label = "-- --nocapture", kind = require("blink.cmp.types").CompletionItemKind.Keyword },
		-- 你还可以添加更多命令，如 clean, doc, fmt, clippy 等
	}

	-- 3. (可选) 根据用户输入过滤补全项
	--    请注意，blink.cmp 本身会进行模糊匹配，这里的过滤可以更精确地控制
	-- local filtered = vim.tbl_filter(function(item)
	--   return vim.startswith(item.label:lower(), input:lower())
	-- end, cargo_commands)

	-- 4. 调用 callback 返回补全结果
	--    注意：blink.cmp 会进一步处理你返回的项，比如进行模糊匹配和排序
	callback({
		items = cargo_commands, -- 或者 filtered
		-- 是否在删除字符时重新请求补全
		is_incomplete_backward = false,
		-- 是否在增加字符时重新请求补全
		is_incomplete_forward = false,
	})
end

-- (可选) 在用户选择某个补全项后，如果需要进行额外操作，可以在这里实现
-- function source:resolve(item, callback)
--   -- 例如，补全时添加详细的文档信息
--   item.documentation = "这是 cargo 命令的详细说明"
--   callback(item)
-- end

return source
