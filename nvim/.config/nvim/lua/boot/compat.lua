-- Neovim 0.13 的 client 方法被 method_wrapper 包过：用点号形式调用
-- （如 `client.supports_method(method)`）仍然能用，但会触发
-- `vim.deprecate("client.supports_method", "client:supports_method", "0.13")`
-- 的提示。本仓库自己的代码早已统一用冒号形式，这条噪音全部来自
-- site/pack 里的上游插件（vim-illuminate、conform.nvim、
-- text-case.nvim、tiny-code-action.nvim、todo2）。
--
-- 这里只吞掉这一条已知噪音，其它 deprecation 照常提示；
-- 上游修好后整文件删除即可（`vim.deprecate` 恢复原实现）。

local orig = vim.deprecate

vim.deprecate = function(name, alt, version, plugin, backtrace)
	if name == "client.supports_method" then
		return
	end
	return orig(name, alt, version, plugin, backtrace)
end
