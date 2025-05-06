local Input = require("nui.input")
local event = require("nui.utils.autocmd").event

-- 禁用的 buftype / filetype
local disabled_buftypes = { terminal = true, prompt = true }
local disabled_filetypes = { TelescopePrompt = true, alpha = true }

-- 历史输入存储
local input_history = {}

-- 获取提示文本
local function get_prompt_text(prompt, default_prompt)
	local prompt_text = prompt or default_prompt
	if prompt_text:sub(-1) == ":" then
		prompt_text = "[" .. prompt_text:sub(1, -2) .. "]"
	end
	return prompt_text
end

-- 自定义 Input 类
local UIInput = Input:extend("UIInput")

function UIInput:init(opts, on_done)
	local border_top_text = get_prompt_text(opts.prompt, "[Input]")
	local default_value = tostring(opts.default or input_history[opts.prompt] or "")

	local relative_mode = opts.relative or "cursor"
	local border_style = opts.border_style or "rounded"
	local winhighlight = opts.winhighlight or "NormalFloat:Normal,FloatBorder:FloatBorder"

	UIInput.super.init(self, {
		relative = relative_mode,
		position = { row = 1, col = 0 },
		size = {
			width = math.max(40, vim.api.nvim_strwidth(default_value)),
		},
		border = {
			style = border_style,
			text = {
				top = border_top_text,
				top_align = "left",
			},
		},
		win_options = {
			winhighlight = winhighlight,
		},
	}, {
		default_value = default_value,
		on_close = function()
			on_done(nil)
		end,
		on_submit = function(value)
			if opts.prompt then
				input_history[opts.prompt] = value -- 存储输入历史
			end
			on_done(value)
		end,
	})

	self:on(event.BufLeave, function()
		on_done(nil)
	end, { once = true })

	self:map("n", "<Esc>", function()
		on_done(nil)
	end, { noremap = true, nowait = true })

	self:map("n", "q", function()
		on_done(nil)
	end, { noremap = true, nowait = true })
end

-- 实例控制变量
local input_ui

vim.ui.input = function(opts, on_confirm)
	assert(type(on_confirm) == "function", "Missing on_confirm callback")

	local buftype = vim.api.nvim_get_option_value("buftype", { buf = 0 })
	local filetype = vim.api.nvim_get_option_value("filetype", { buf = 0 })

	if disabled_buftypes[buftype] or disabled_filetypes[filetype] then
		vim.notify("当前 buffer 类型禁用输入框", vim.log.levels.WARN)
		return
	end

	if input_ui then
		vim.notify("Busy: another input is pending!", vim.log.levels.WARN)
		return
	end

	input_ui = UIInput(opts, function(value)
		if input_ui then
			input_ui:unmount()
		end
		on_confirm(value)
		input_ui = nil
	end)

	input_ui:mount()
end
