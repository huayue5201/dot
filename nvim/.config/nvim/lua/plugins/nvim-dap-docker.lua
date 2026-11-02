-- https://github.com/docker/nvim-dap-docker
-- 把 buildx 的 DAP（`docker buildx debug`）接进 nvim-dap：可以像调试程序一样
-- 调试 `docker build` —— 在 Dockerfile 的 RUN 上打断点、单步、看变量/文件系统。
-- 依赖：nvim >= 0.11、buildx >= 0.29（本机 v0.37.2 已满足）。
-- 用法：打开 Dockerfile，<leader>dr（dap continue）→ 选一个 Build 变体。
-- 注意：buildx 的 DAP 还是 experimental，插件也只有 1 个文件，行为可能变。
return {
	"docker/nvim-dap-docker",
	dependencies = { "mfussenegger/nvim-dap" },
	config = function(_, opts)
		require("dap-docker").setup(opts)
		-- 上游 bug：setup() 内部调 setup_dockerfile_configuration(dap) 时漏传了配置，
		-- opts.dap_configurations 会被静默忽略（只剩 4 个内置 Build 变体）。
		-- 所以自定义变体在这里手动追加。
		table.insert(require("dap").configurations.dockerfile, {
			type = "dockerfile",
			name = "Build (Cache-Only)",
			request = "launch",
			dockerfile = "${file}",
			contextPath = "${workspaceFolder}",
			args = { "-o", "type=cacheonly" },
		})
	end,

	opts = {
		docker = {
			path = "docker", -- 调试时用的 docker 可执行文件（默认 PATH 里的 docker）
			builder = nil, -- 指定 buildx builder；nil = 用当前 context 的默认 builder
			standalone = false, -- true = 直接调用 buildx 二进制而不是 `docker buildx` 插件
		},
	},
}
