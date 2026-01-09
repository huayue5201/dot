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

pip3_install_parallel() {
  local packages=("$@")
  for pkg in "${packages[@]}"; do
    if ! pip3 show "$pkg" &>/dev/null; then
      log "开始安装 pip3 包 $pkg ..."
      pip3 install "$pkg" &
    else
      log "pip3 包 $pkg 已安装，跳过"
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
# 1. 基础工具并行安装
# -----------------------------
log "安装基础工具..."
brew_install_parallel stow git lazygit fzf fd ripgrep bat btop tmux aria2 llvm lsusb zoxide jless otree jiq jq rust universal-ctags
brew install --HEAD neovim # neovim 建议单独安装，避免 HEAD 并行冲突

# -----------------------------
# 2. dotfiles 管理（顺序执行）
# -----------------------------
DOTFILES_DIR="$HOME/dotfile"
if [ -d "$DOTFILES_DIR" ]; then
  log "开始 stow 链接 dotfiles..."
  cd "$DOTFILES_DIR"
  for d in git nvim ghostty btop tmux aria2; do
    stow "$d" || warn "stow $d 失败"
  done
else
  warn "$DOTFILES_DIR 不存在，跳过 dotfiles 链接"
fi

# -----------------------------
# 3. MCU 开发环境并行安装
# -----------------------------
log "安装 MCU 开发环境..."
brew_install_parallel openocd telnet node
brew_install --cask gcc-arm-embedded # cask 建议单独安装
pip3_install_parallel compiledb

# -----------------------------
# 4. LSP / 语言工具并行安装
# -----------------------------
log "安装 LSP 和语言工具..."
brew_install_parallel taplo stylua uv rust-analyzer emmylua_ls ast-grep ruff
if command_exists uv; then
  uv tool install ty@latest || warn "uv tool install ty@latest 失败"
fi

# -----------------------------
# 4. json 工具并行安装
# -----------------------------
log "安装json工具..."
brew_install_parallel jless jq jiq otree

# -----------------------------
# 5. Brew 扩展（顺序执行即可）
# -----------------------------
brew tap buo/cask-upgrade || true
brew tap beeftornado/rmtre || true

# -----------------------------
# 6. Cask 应用 & 字体并行安装
# -----------------------------
log "安装 cask 应用和字体..."
brew_cask_install_parallel orbstack ghostty
brew tap homebrew/cask-fonts || true
brew_cask_install_parallel font-fira-code-nerd-font font-victor-mono-nerd-font font-gohufont-nerd-font font-anonymice-nerd-font font-terminess-ttf-nerd-font

# -----------------------------
# 7. Rust 安装（顺序执行）
# -----------------------------
if ! command_exists rustc; then
  log "安装 Rust..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
else
  log "Rust 已安装，跳过"
fi

# -----------------------------
# 8. 完成提示
# -----------------------------
log "======================="
log "一键环境部署完成！"
log "建议操作："
log "  - brew cu 升级 cask"
log "  - uv tool upgrade 更新 python 工具"
log "======================="
