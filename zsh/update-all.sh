#!/usr/bin/env zsh
set -euo pipefail

# ------------------------------
# 配置
# ------------------------------
LOG_FILE="$HOME/update-all.log"
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
echo "🧩 开始更新所有包管理器..." | tee "$LOG_FILE"
echo "🧾 日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
echo "🕐 开始时间: $(date)" | tee -a "$LOG_FILE"

# ------------------------------
# 系统信息
# ------------------------------
echo -e "\n💻 系统信息:" | tee -a "$LOG_FILE"
echo "系统: $(uname -a)" | tee -a "$LOG_FILE"
echo "Shell: $SHELL" | tee -a "$LOG_FILE"
echo "用户: $(whoami)" | tee -a "$LOG_FILE"

# ------------------------------
# 当前 PATH 优先级
# ------------------------------
echo -e "\n🔍 当前 PATH 路径优先级：" | tee -a "$LOG_FILE"
i=1
for p in $(echo $PATH | tr ':' ' '); do
    echo "  [$i] $p" | tee -a "$LOG_FILE"
    ((i++))
done

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

# ------------------------------
# Homebrew
# ------------------------------
echo -e "\n${BLUE}🧠 🍺 更新 Homebrew...${RESET}" | tee -a "$LOG_FILE"
if command -v brew &>/dev/null; then
    retry_command "brew update" | tee -a "$LOG_FILE" || true
    retry_command "brew upgrade" | tee -a "$LOG_FILE" || true
    retry_command "brew cleanup -s" | tee -a "$LOG_FILE" || true
    retry_command "brew autoremove" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ Homebrew 更新与清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ Homebrew 未安装${RESET}" | tee -a "$LOG_FILE"
fi

# ------------------------------
# npm
# ------------------------------
echo -e "\n${BLUE}🧠 📦 更新 npm...${RESET}" | tee -a "$LOG_FILE"
if command -v npm &>/dev/null; then
    retry_command "npm update -g" | tee -a "$LOG_FILE" || true
    retry_command "npm cache clean --force" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ npm 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ npm 未安装${RESET}" | tee -a "$LOG_FILE"
fi

# ------------------------------
# yarn
# ------------------------------
echo -e "\n${BLUE}🧠 🧶 更新 yarn...${RESET}" | tee -a "$LOG_FILE"
if command -v yarn &>/dev/null; then
    retry_command "corepack prepare yarn@stable --activate" | tee -a "$LOG_FILE" || true
    retry_command "yarn cache clean" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ yarn 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ yarn 未安装${RESET}" | tee -a "$LOG_FILE"
fi

# ------------------------------
# bun
# ------------------------------
echo -e "\n${BLUE}🧠 🥯 更新 bun...${RESET}" | tee -a "$LOG_FILE"
if command -v bun &>/dev/null; then
    retry_command "bun upgrade" | tee -a "$LOG_FILE" || true
    retry_command "bun pm cache clean" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ bun 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ bun 未安装${RESET}" | tee -a "$LOG_FILE"
fi

# ------------------------------
# Python (uv 优先)
# ------------------------------
echo -e "\n${BLUE}🧠 ⚡ 更新 Python 包 (使用 uv)...${RESET}" | tee -a "$LOG_FILE"
if command -v uv &>/dev/null; then
    echo "📊 uv 版本: $(uv --version)" | tee -a "$LOG_FILE"
    retry_command "uv tool upgrade --all" | tee -a "$LOG_FILE" || true
    retry_command "uv cache prune" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ uv 更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ uv 未找到，跳过 Python 包更新${RESET}" | tee -a "$LOG_FILE"
fi

# ------------------------------
# Rust (cargo + rustup)
# ------------------------------
echo -e "\n${BLUE}🧠 🦀 更新 Rust...${RESET}" | tee -a "$LOG_FILE"
if command -v rustup &>/dev/null; then
    retry_command "rustup update" | tee -a "$LOG_FILE" || true
    echo -e "${GREEN}✅ rustup 更新与清理完成${RESET}" | tee -a "$LOG_FILE"
else
    echo -e "${YELLOW}⚠️ rustup 未安装${RESET}" | tee -a "$LOG_FILE"
fi

if command -v cargo &>/dev/null; then
    echo "🔄 更新 cargo 包..." | tee -a "$LOG_FILE"
    if cargo install-update --help &>/dev/null; then
        retry_command "cargo install-update -a" | tee -a "$LOG_FILE" || true
        if cargo cache -a &>/dev/null; then
            retry_command "cargo cache -a" | tee -a "$LOG_FILE" || true
        fi
        echo -e "${GREEN}✅ cargo 包更新与缓存清理完成${RESET}" | tee -a "$LOG_FILE"
    else
        echo -e "${YELLOW}ℹ️ 未安装 cargo-update，可执行: cargo install cargo-update${RESET}" | tee -a "$LOG_FILE"
    fi
fi

# ------------------------------
# 完成统计
# ------------------------------
END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

echo -e "\n${BOLD}${GREEN}🎉 所有更新完成！${RESET}" | tee -a "$LOG_FILE"
echo "⏱️ 总耗时: ${DURATION}秒" | tee -a "$LOG_FILE"
echo "📁 日志文件: $LOG_FILE" | tee -a "$LOG_FILE"
echo "🕐 完成时间: $(date)" | tee -a "$LOG_FILE"

# ------------------------------
# 显示日志文件位置
# ------------------------------
echo -e "\n${BLUE}🔍 查看完整日志:${RESET}"
echo "   tail -f $LOG_FILE"

