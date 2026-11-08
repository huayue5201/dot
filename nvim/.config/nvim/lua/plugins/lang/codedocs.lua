-- https://github.com/jeangiraldoo/codedocs.nvim
--
-- 只在插件真正支持的文件类型里挂 `gcd`：codedocs 的 _determine_lang_name() 对
-- 未支持的 ft 返回 nil，随后 get_target_data 里的 vim.validate 直接抛
-- "lang_name: expected string, got nil"。所以按 ft 白名单做 buffer-local 映射
-- （白名单从插件自己的 config 读，避免手抄一份会漂移）。
return {
	"jeangiraldoo/codedocs.nvim",
	config = function()
		-- 支持的 ft 取自插件默认配置：c/cpp/gdscript/go/html/java/javascript/
		-- kotlin/lua/markdown/php/python/query/ruby/rust/sh/sql/toml/typescript
		local function supported(ft)
			local ok, langs = pcall(function()
				return require("codedocs.config").opts.languages
			end)
			if not ok or type(langs) ~= "table" then
				return false
			end
			for _, opts in pairs(langs) do
				for _, candidate in ipairs(opts.filetypes or {}) do
					if candidate == ft then
						return true
					end
				end
			end
			return false
		end

		local function install(buf)
			if not vim.api.nvim_buf_is_valid(buf) then
				return
			end
			-- FileType 会重复触发，先清掉旧映射
			pcall(vim.keymap.del, "n", "gcd", { buffer = buf })
			if supported(vim.bo[buf].filetype) then
				vim.keymap.set("n", "gcd", "<cmd>Codedocs<cr>", {
					buffer = buf,
					desc = "插入代码注释",
				})
			end
		end

		vim.api.nvim_create_autocmd("FileType", {
			group = vim.api.nvim_create_augroup("codedocs_ft_guard", { clear = true }),
			callback = function(event)
				install(event.buf)
			end,
		})

		for _, buf in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(buf) then
				install(buf)
			end
		end
	end,
}
