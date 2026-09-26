# dotfiles

个人开发环境配置集合，采用「stow 风格」目录组织，涵盖 shell、编辑器、终端与各类命令行工具。

> ⚠️ 本仓库为公开仓库，所有提交（含完整历史）均已经过脱敏处理：不含真实用户名、家目录绝对路径、私有 IP、服务器域名、密钥等敏感信息。历史中的身份统一为 `huayue5201 <huayue5201@users.noreply.github.com>`。

## 目录结构

```
.
├── nvim/          # Neovim 配置（lazy.nvim + LSP + DAP + 大量插件）
├── zsh/           # zsh 配置（.zshrc、.zshenv、脚本）
├── tmux/          # tmux 配置
├── git/           # git 全局配置（.gitconfig、.gitignore_global）
├── ghostty/       # Ghostty 终端配置
├── kitty/         # Kitty 终端配置
├── aria2/         # aria2 下载器配置
├── herdr/         # herdr 会话管理配置
├── jiq/           # jiq 工具配置
├── lspmux/        # lspmux 配置
├── xray/          # xray 配置（已替换为占位符）
└── install_dev_tools.sh  # 开发工具安装脚本
```

## 特性

- **Neovim**：基于 [lazy.nvim](https://github.com/folke/lazy.nvim) 管理 120+ 插件，重度懒加载，模块化拆分（`lua/plugins/*.lua`），内置 LSP / DAP / 格式化 / 补全等完整配置。
- **跨平台路径**：所有机器相关的绝对路径已替换为 `~` / `$HOME` / `vim.fn.expand()` 等可移植写法。
- **无敏感信息**：API Key 一律通过环境变量注入（如 `DEEPSEEK_API_KEY`），不落盘到仓库。

## 安装

各目录下的文件按「去掉 `.config` / 前导点」后的路径，软链或复制到 `$HOME` 对应位置。推荐使用 [GNU Stow](https://www.gnu.org/software/stow/)：

```bash
git clone git@github.com:huayue5201/dot.git ~/dotfiles
cd ~/dotfiles

# 逐个模块部署，例如：
stow -t ~ nvim
stow -t ~ zsh
stow -t ~ git
stow -t ~ tmux
```

> 注意：部分配置（如 xray、nvim 的 DAP 路径）为占位符或示例值，部署后需按本机实际情况修改。

## 环境要求

- macOS / Linux
- Neovim 0.13+（nightly）
- zsh、tmux、git
- Node.js、Python3（供部分 LSP / 插件使用）

## 隐私说明

提交历史已用 `git filter-repo` 重写，移除了以下信息：

- 真实用户名与家目录绝对路径（`/Users/<name>` 等）
- 私有 IP（`192.168.*` 等，含提交作者邮箱中的 IP）
- 服务器域名、UUID、证书路径等凭据
- 个人邮箱（QQ 邮箱等）

所有提交者身份统一映射为 GitHub noreply 邮箱，避免泄露真实姓名与邮箱。
