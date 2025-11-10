local M = {}

M.envs = {}

function M.register_env(name, env)
	if not name or not env then
		return
	end
	M.envs[name] = env
end

function M.auto_detect_env()
	for name, env in pairs(M.envs) do
		if env.detect then
			local ok, detected = pcall(env.detect)
			if ok and detected and M.envs[detected] then
				return detected
			end
		end
	end
	return nil
end

return M
