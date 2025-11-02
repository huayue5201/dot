local M = {}

M.envs = {}

--- 注册环境模块
---@param name string
---@param env table { name, type, detect=function, apply=function }
function M.register_env(name, env)
	if not name or not env then
		return
	end
	M.envs[name] = env
end

--- 自动检测当前环境
function M.auto_detect_env()
	for name, env in pairs(M.envs) do
		if env.detect then
			local ok, detected = pcall(env.detect, M.envs)
			if ok and detected and M.envs[detected] then
				return detected
			end
		end
	end
	return nil
end

return M
