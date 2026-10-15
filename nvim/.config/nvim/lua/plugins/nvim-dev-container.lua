-- https://github.com/esensar/nvim-dev-container
-- VSCode "Remote - Containers" 的 nvim 版：读 .devcontainer.json，用 docker/podman
-- 起容器，并把 nvim 以 client/server 模式嵌入容器内运行（不支持时退回 :terminal buffer）。
-- 要求：nvim >= 0.12（本机 0.13.0-dev ✓）、nvim-treesitter 的 json parser（✓）。
-- 本机容器运行时就绪状态：只有 docker（无 podman / devcontainer-cli）。
return {
	"esensar/nvim-dev-container",
	dependencies = { "nvim-treesitter/nvim-treesitter" },
	-- 懒加载：setup 时才生成这些命令，故用 cmd / keys 触发。
	cmd = {
		"DevcontainerStart",
		"DevcontainerAttach",
		"DevcontainerExec",
		"DevcontainerStop",
		"DevcontainerStopAll",
		"DevcontainerRemoveAll",
		"DevcontainerLogs",
		"DevcontainerEditNearestConfig",
	},
	keys = {
		{ "<leader>Ds", "<cmd>DevcontainerStart<cr>", desc = "Docker/DevContainer: 启动容器" },
		{ "<leader>Da", "<cmd>DevcontainerAttach<cr>", desc = "Docker/DevContainer: 附加到容器 (nvim client/server)" },
		{ "<leader>De", "<cmd>DevcontainerExec<cr>", desc = "Docker/DevContainer: 容器内执行命令" },
		{ "<leader>Dx", "<cmd>DevcontainerStop<cr>", desc = "Docker/DevContainer: 停止容器" },
		{ "<leader>DX", "<cmd>DevcontainerStopAll<cr>", desc = "Docker/DevContainer: 停止全部" },
		{ "<leader>DR", "<cmd>DevcontainerRemoveAll<cr>", desc = "Docker/DevContainer: 移除全部容器/镜像" },
		{ "<leader>Dl", "<cmd>DevcontainerLogs<cr>", desc = "Docker/DevContainer: 查看日志" },
		{ "<leader>Dc", "<cmd>DevcontainerEditNearestConfig<cr>", desc = "Docker/DevContainer: 编辑/新建 devcontainer.json" },
	},
	opts = {
		-- 本机只有 docker，显式指定避免默认先试 podman。
		container_runtime = "docker",
		-- 默认不自动起容器（attach/dev 挂载保持默认）。
		autocommands = {
			init = false,
			clean = false,
			update = false,
		},
	},
}
