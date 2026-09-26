#!/usr/bin/env bash
set -euo pipefail

echo "======================="
echo "一键环境部署脚本开始"
echo "======================="

# -----------------------------
# 工具函数
# -----------------------------
log() { echo -e "\033[1;34m[INFO]\033[0m $*"; }
warn() { echo -e "\033[1;33m[WARN]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

command_exists() { command -v "$1" &>/dev/null; }

# -----------------------------
# 并行安装工具
# -----------------------------
brew_install_parallel() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    if ! brew list "$pkg" &>/dev/null; then
      log "开始安装 $pkg ..."
      brew install "$pkg" &
    else
      log "$pkg 已安装，跳过"
    fi
  done
  wait
}

brew_cask_install_parallel() {
  local casks=("$@")
  for cask in "${casks[@]}"; do
    if ! brew list --cask "$cask" &>/dev/null; then
      log "开始安装 cask $cask ..."
      brew install --cask "$cask" &
    else
      log "cask $cask 已安装，跳过"
    fi
  done
  wait
}

uv_tool_install() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    if ! uv tool list 2>/dev/null | awk '{print $1}' | grep -qx "$pkg"; then
      log "开始安装 uv 工具 $pkg ..."
      uv tool install "$pkg" &
    else
      log "uv 工具 $pkg 已安装，跳过"
    fi
  done
  wait
}

# -----------------------------
# Homebrew 安装和更新
# -----------------------------
if ! command_exists brew; then
  log "Homebrew 未安装，开始安装..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
else
  log "Homebrew 已安装，更新中..."
  brew update
  brew upgrade
fi

# -----------------------------
# 第三方 tap（须先于 jiq 安装）
# -----------------------------
brew tap bellicose100xp/tap || true

# -----------------------------
# 1. 基础工具并行安装
# -----------------------------
log "安装基础工具..."
# 注：
#   - orbstack 是 cask 应用，见第 6 步
#   - rust 由 rustup 安装（见第 7 步），这里不再用 brew 装
#   - llvm 已移除：clangd 由 mason 提供，无需 brew 的巨型 llvm
#   - openocd 的 formula 名是 open-ocd（带连字符），见第 3 步
brew_install_parallel stow git lazygit fzf fd ripgrep bat btop lsusb zoxide jless otree jiq jq universal-ctags tree-sitter-cli tmux aria2 node

# -----------------------------
# 2. dotfiles 管理（顺序执行）
# -----------------------------
DOTFILES_DIR="$HOME/dotfiles"
if [ -d "$DOTFILES_DIR" ]; then
  log "开始 stow 链接 dotfiles..."
  cd "$DOTFILES_DIR"
  for d in git nvim ghostty tmux aria2 zsh herdr jiq kitty xray; do
    stow "$d" || warn "stow $d 失败"
  done
else
  warn "$DOTFILES_DIR 不存在，跳过 dotfiles 链接"
fi

# -----------------------------
# 3. MCU 开发环境并行安装
# -----------------------------
log "安装 MCU 开发环境..."
brew_install_parallel open-ocd telnet
brew install --cask gcc-arm-embedded # cask 建议单独安装
uv_tool_install compiledb

# -----------------------------
# 4. LSP / 语言工具并行安装
# -----------------------------
log "安装 LSP 和语言工具..."
brew_install_parallel uv ast-grep
if command_exists uv; then
  uv tool install ty || warn "uv tool install ty 失败"
fi

# -----------------------------
# 5. Cask 应用 & 字体并行安装
# -----------------------------
log "安装 cask 应用和字体..."
# 字体已全部迁移到 homebrew/cask 核心，无需再 tap homebrew/cask-fonts
brew_cask_install_parallel orbstack ghostty kitty
brew_cask_install_parallel font-fira-code-nerd-font font-victor-mono-nerd-font font-gohufont-nerd-font font-anonymice-nerd-font font-terminess-ttf-nerd-font

# -----------------------------
# 6. Rust 安装（顺序执行）
# -----------------------------
if ! command_exists rustc; then
  log "安装 Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  log "Rust 已安装，跳过"
fi

# -----------------------------
# 7. 完成提示
# -----------------------------
log "======================="
log "一键环境部署完成！"
log "建议操作："
log "  - brew upgrade --cask 升级 cask 应用（旧 brew cu 已废弃）"
log "  - uv tool upgrade --all 更新 python 工具"
log "======================="
