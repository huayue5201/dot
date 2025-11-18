#!/usr/bin/env bash
export PATH="/opt/homebrew/bin:$PATH"
set -euo pipefail

# ==============================================================
# 🌈 全能更新脚本 (增强版)
# 支持 Homebrew / npm / yarn / bun / uv / cargo / git clone 仓库
# 可按模块执行： ./update-all.sh git | system | all
# ==============================================================

# ------------------------------
# 模式选择
# ------------------------------
MODE="${1:-all}" # 默认 all，可选：system / git

should_run() {
  local section="$1"
  [[ "$MODE" == "all" || "$MODE" == "$section" ]]
}

# ------------------------------
# 配置
# ------------------------------
LOG_FILE="$HOME/update-all.log"
GIT_CONF="$HOME/.update-all-git.conf"
START_TIME=$(date +%s)

# ------------------------------
# 颜色定义
# ------------------------------
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

# ------------------------------
# 初始化日志
# ------------------------------
{
  echo -e "\n=============================================="
  echo "🧩 开始更新所有模块..."
  echo "🕐 开始时间: $(date)"
  echo "📁 日志文件: $LOG_FILE"
  echo "=============================================="
  echo "💻 系统信息:"
  echo "系统: $(uname -a)"
  echo "Shell: $0 ($SHELL)"
  echo "用户: $(whoami)"
  echo
} | tee -a "$LOG_FILE"

# ------------------------------
# 错误重试函数
# ------------------------------
retry_command() {
  local cmd="$1"
  local max_attempts=3
  local attempt=1

  while [ $attempt -le $max_attempts ]; do
    if eval "$cmd"; then
      return 0
    fi
    echo -e "${YELLOW}⚠️ 尝试 $attempt/$max_attempts 失败，重试...${RESET}" | tee -a "$LOG_FILE"
    sleep 2
    ((attempt++))
  done
  echo -e "${RED}❌ 命令失败: $cmd${RESET}" | tee -a "$LOG_FILE"
  return 1
}

# ==============================================================
# 🍺 系统类更新
# ==============================================================
if should_run system; then
  echo -e "\n${BOLD}${BLUE}🧠 [系统模块] 更新系统包管理器...${RESET}" | tee -a "$LOG_FILE"

  # --- Homebrew ---
  if command -v brew &>/dev/null; then
    echo -e "\n${BLUE}🍺 更新 Homebrew...${RESET}" | tee -a "$LOG_FILE"
    retry_command "brew update" | tee -a "$LOG_FILE" || true
    retry_command "brew upgrade" | tee -a "$LOG_FILE" || true
    retry_command "brew cleanup -s" | tee -a "$LOG_FILE" || true
    retry_command "brew autoremove" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ Homebrew 更新与清理完成${RESET}" | tee -a "$LOG_FILE"
  else
    echo -e "${YELLOW}⚠️ Homebrew 未安装${RESET}" | tee -a "$LOG_FILE"
  fi

  # --- npm ---
  if command -v npm &>/dev/null; then
    echo -e "\n${BLUE}📦 更新 npm...${RESET}" | tee -a "$LOG_FILE"
    retry_command "npm update -g" | tee -a "$LOG_FILE" || true
    retry_command "npm cache clean --force" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ npm 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
  else
    echo -e "${YELLOW}⚠️ npm 未安装${RESET}" | tee -a "$LOG_FILE"
  fi

  # --- yarn ---
  if command -v yarn &>/dev/null; then
    echo -e "\n${BLUE}🧶 更新 yarn...${RESET}" | tee -a "$LOG_FILE"
    retry_command "corepack prepare yarn@stable --activate" | tee -a "$LOG_FILE" || true
    retry_command "yarn cache clean" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ yarn 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
  else
    echo -e "${YELLOW}⚠️ yarn 未安装${RESET}" | tee -a "$LOG_FILE"
  fi

  # --- bun ---
  if command -v bun &>/dev/null; then
    echo -e "\n${BLUE}🥯 更新 bun...${RESET}" | tee -a "$LOG_FILE"
    retry_command "bun upgrade" | tee -a "$LOG_FILE" || true
    retry_command "bun pm cache clean" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ bun 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
  else
    echo -e "${YELLOW}⚠️ bun 未安装${RESET}" | tee -a "$LOG_FILE"
  fi

  # --- Python (uv + pip3 专业版混合更新) ---
  echo -e "\n${BLUE}🐍 Python 包更新 (专业版：区分 uv / pip 管理)...${RESET}" | tee -a "$LOG_FILE"

  # ----------------------------------------
  # 1) 优先升级 uv tools
  # ----------------------------------------
  UV_TOOLS=""
  if command -v uv &>/dev/null; then
    if uv tool list &>/dev/null; then
      UV_TOOLS=$(uv tool list 2>/dev/null | awk '{print $1}' | grep -v '^$' | tr '\n' ' ')
    fi

    if [ -z "$UV_TOOLS" ]; then
      echo -e "${YELLOW}⚠️ uv 未安装任何工具${RESET}" | tee -a "$LOG_FILE"
    else
      echo -e "${BLUE}🔍 uv 管理的工具: ${UV_TOOLS}${RESET}" | tee -a "$LOG_FILE"
    fi
  else
    echo -e "${YELLOW}⚠️ 未检测到 uv，跳过 uv 工具更新${RESET}" | tee -a "$LOG_FILE"
  fi

  # ----------------------------------------
  # 2) pip3 更新 Python 库（排除 uv tools）
  # ----------------------------------------
  if command -v pip3 &>/dev/null; then
    echo -e "\n${BLUE}📦 使用 pip3 升级 Python 库（自动避开 uv 工具）...${RESET}" | tee -a "$LOG_FILE"

    # 升级 pip 自身
    retry_command "pip3 install --upgrade pip setuptools wheel" | tee -a "$LOG_FILE" || true

    # 获取所有 pip 包
    PIP_PACKAGES=$(pip3 list --format=freeze 2>/dev/null | cut -d '=' -f1)

    for pkg in $PIP_PACKAGES; do
      # 跳过 uv 管理的包
      if [ -n "$UV_TOOLS" ] && echo "$UV_TOOLS" | grep -q "^${pkg}$"; then
        echo -e "${YELLOW}⏭  跳过已由 uv 管理的包: ${pkg}${RESET}" | tee -a "$LOG_FILE"
        continue
      fi

      # 跳过本地 / editable 包
      if pip3 show "$pkg" 2>/dev/null | grep -q "Location: .*site-packages"; then
        retry_command "pip3 install -U \"$pkg\"" | tee -a "$LOG_FILE" || true
      else
        echo -e "${YELLOW}⏭  跳过本地/开发者模式包: ${pkg}${RESET}" | tee -a "$LOG_FILE"
      fi
    done

    # 清理 pip 缓存
    pip3 cache purge 2>/dev/null || true
    echo -e "${GREEN}✅ pip3 更新完成${RESET}" | tee -a "$LOG_FILE"

  else
    echo -e "${YELLOW}⚠️ pip3 未安装${RESET}" | tee -a "$LOG_FILE"
  fi

  echo -e "${GREEN}🎉 Python 模块（uv + pip）已安全完成更新${RESET}" | tee -a "$LOG_FILE"

  # --- Rust ---
  if command -v rustup &>/dev/null; then
    echo -e "\n${BLUE}🦀 更新 Rust...${RESET}" | tee -a "$LOG_FILE"
    retry_command "rustup update" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ rustup 更新完成${RESET}" | tee -a "$LOG_FILE"
  fi

  if command -v cargo &>/dev/null; then
    if cargo install-update --help &>/dev/null; then
      retry_command "cargo install-update -a" | tee -a "$LOG_FILE" || true
    else
      echo -e "${YELLOW}⚠️ cargo-install-update 未安装，跳过 cargo 包更新${RESET}" | tee -a "$LOG_FILE"
    fi
    echo -e "${GREEN}✅ cargo 包更新完成${RESET}" | tee -a "$LOG_FILE"
  fi

  echo -e "\n${BOLD}${GREEN}✅ 系统包管理器更新完成${RESET}" | tee -a "$LOG_FILE"
fi

# ==============================================================
# 🌀 Git 仓库更新 (配置驱动)
# ==============================================================
if should_run git; then
  echo -e "\n${BOLD}${BLUE}🧠 [Git 模块] 更新手动 clone 的仓库...${RESET}" | tee -a "$LOG_FILE"

  if [ ! -f "$GIT_CONF" ]; then
    echo -e "${YELLOW}⚠️ 未找到配置文件: $GIT_CONF${RESET}" | tee -a "$LOG_FILE"
    echo -e "${BLUE}💡 创建示例配置: $GIT_CONF${RESET}" | tee -a "$LOG_FILE"
    cat >"$GIT_CONF" <<'EOF'
# Git 仓库配置
# 每行一个仓库路径，支持 ~ 扩展
# 格式1: 直接路径
# /path/to/repo

# 格式2: 自动克隆 (源URL -> 目标路径)
# https://github.com/user/repo.git -> ~/Projects/repo

# 示例:
# ~/Projects/my-project
# https://github.com/username/repo.git -> ~/Projects/repo
EOF
  else
    echo "📘 使用配置文件: $GIT_CONF" | tee -a "$LOG_FILE"

    SUCCESS_COUNT=0
    SKIP_COUNT=0
    FAIL_COUNT=0

    # 顺序执行 Git 更新（更稳定）
    while IFS= read -r line || [ -n "$line" ]; do
      # 跳过空行和注释
      line=$(echo "$line" | sed 's/#.*$//' | tr -d '[:space:]')
      [ -z "$line" ] && continue

      echo -e "\n${BLUE}🔄 处理: $line${RESET}" | tee -a "$LOG_FILE"

      # 处理 "url -> path" 格式
      if [[ "$line" == *"->"* ]]; then
        src=$(echo "$line" | awk -F'->' '{print $1}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        dest=$(echo "$line" | awk -F'->' '{print $2}' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        dest=$(eval echo "$dest") # 展开 ~

        if [ ! -d "$dest/.git" ]; then
          echo "🚧 克隆新仓库: $src -> $dest" | tee -a "$LOG_FILE"
          if git clone "$src" "$dest" >>"$LOG_FILE" 2>&1; then
            echo -e "${GREEN}✅ 克隆成功: $dest${RESET}" | tee -a "$LOG_FILE"
            ((SUCCESS_COUNT++))
          else
            echo -e "${RED}❌ 克隆失败: $dest${RESET}" | tee -a "$LOG_FILE"
            ((FAIL_COUNT++))
          fi
          continue
        else
          repo="$dest"
        fi
      else
        repo=$(eval echo "$line") # 展开 ~
      fi

      # 检查是否为 Git 仓库
      if [ ! -d "$repo/.git" ]; then
        echo -e "${YELLOW}⚠️ 跳过 $repo (非 Git 仓库)${RESET}" | tee -a "$LOG_FILE"
        ((SKIP_COUNT++))
        continue
      fi

      # 检查是否有未提交的修改
      cd "$repo"
      if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
        echo -e "${YELLOW}⚠️ 跳过 $repo (有未提交修改)${RESET}" | tee -a "$LOG_FILE"
        ((SKIP_COUNT++))
        continue
      fi

      # 执行 Git 更新
      if git pull --rebase --autostash >>"$LOG_FILE" 2>&1; then
        echo -e "${GREEN}✅ 成功更新 $repo${RESET}" | tee -a "$LOG_FILE"
        ((SUCCESS_COUNT++))
      else
        echo -e "${RED}❌ 更新失败 $repo${RESET}" | tee -a "$LOG_FILE"
        ((FAIL_COUNT++))
      fi

    done <"$GIT_CONF"

    echo -e "\n${BOLD}${BLUE}📊 Git 仓库更新统计:${RESET}" | tee -a "$LOG_FILE"
    echo -e "${GREEN}✅ 成功: $SUCCESS_COUNT${RESET}" | tee -a "$LOG_FILE"
    echo -e "${YELLOW}⏭️ 跳过: $SKIP_COUNT${RESET}" | tee -a "$LOG_FILE"
    echo -e "${RED}❌ 失败: $FAIL_COUNT${RESET}" | tee -a "$LOG_FILE"
  fi
fi

# ==============================================================
# ✅ 结束统计
# ==============================================================
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${BOLD}${GREEN}🎉 所有更新任务完成${RESET}" | tee -a "$LOG_FILE"
echo "⏱️ 总耗时: ${DURATION}秒" | tee -a "$LOG_FILE"
echo "🕐 完成时间: $(date)" | tee -a "$LOG_FILE"

echo -e "\n${BLUE}🔍 查看完整日志:${RESET}"
echo "   tail -f $LOG_FILE"
