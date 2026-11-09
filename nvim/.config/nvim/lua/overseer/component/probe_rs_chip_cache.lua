-- 把 `probe-rs info` 输出里的 "Detected chip: X" 自动存进芯片缓存。
-- 由 overseer 模板 user/probe_rs.lua 的 info 任务引用。
-- 组件名 = 文件名，所以是 "probe_rs_chip_cache"。
-- 缓存槽位按 `--probe` 选择器区分：一块板一个探头时，插哪块板就是哪颗芯片。

---@type overseer.ComponentFileDefinition
return {
	desc = "Cache the chip auto-detected by `probe-rs info`",
	params = {},
	constructor = function()
		local saved = false
		return {
			on_output_lines = function(_, task, lines)
				if saved then
					return
				end
				for _, line in ipairs(lines) do
					local chip = line:match("Detected chip:%s*(%S.*)$")
					if chip then
						chip = vim.trim(chip)
						local probe = ""
						local from_template = task.from_template
						if from_template and from_template.params then
							probe = from_template.params.probe or ""
						end
						require("lib.probe_rs").save_probe_chip(chip, probe)
						saved = true
						vim.notify(
							("probe-rs: 已识别并缓存芯片 %s（探头 %s），之后烧录直接用它"):format(
								chip,
								probe ~= "" and probe or "default"
							),
							vim.log.levels.INFO
						)
						return
					end
				end
			end,
		}
	end,
}
