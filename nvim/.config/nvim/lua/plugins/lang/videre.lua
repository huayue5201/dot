-- https://github.com/huayue5201/videre.nvim
--
-- 把 JSON / TOML / YAML / XML 画成「表格连线图」，在 terminal 风格的浮窗里展开/折叠/跳转，
-- 不用离开编辑器去开 JSON Crack。
--
-- 用这个 fork 而不是上游 Owen-Dechow/videre.nvim：它只多一个提交，
-- `fix: 正确处理宽字符/多字节的显示列到字节转换`——中文键值不会错位，正是我们需要的。
--
-- 解析器是可选的：JSON 走内置 vim.json，其余三种各是一个小插件。缺哪个只是该文件类型
-- 用不了（:Videre 会提示 `xxx is not a valid Videre data type.`），不会报启动错误。
-- 用法：在 json/toml/yaml/xml buffer 里 :Videre 或 <localleader>vv。
-- 图内键位：E 展开/折叠 · L 进入子表 · H 回父表 · J/K 上下移动 · R 设为根 · u/<C-r> 撤销重做 · q 关闭 · ? 帮助
return {
	"huayue5201/videre.nvim",
	dependencies = {
		"Owen-Dechow/graph_view_yaml_parser", -- YAML
		"Owen-Dechow/graph_view_toml_parser", -- TOML
		"a-usr/xml2lua.nvim", -- XML（实验性）
	},
	opts = {
		-- 读 README 建议的 sharp 方角；想要默认圆角就删掉这一行
		box_style = "sharp",
	},
	keys = {
		{ "<localleader>vv", "<cmd>Videre<cr>", desc = "Videre: JSON/YAML/TOML graphical viewer" },
	},
}
