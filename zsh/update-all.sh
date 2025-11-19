#!/usr/bin/env bash
# update-all.sh (专业版)
# 强化：兼容 Homebrew Cask 冲突、PEP 668 externall-managed 环境、临时 venv 回退策略
# 用法: ./update-all.sh [all|system|git]
set -euo pipefail

# -------------------------
# 配置（可按需修改）
# -------------------------
MODE="${1:-all}" # all / system / git
LOG_FILE="${HOME}/update-all.log"
GIT_CONF="${HOME}/.update-all-git.conf"
TMP_VENV_BASE="${TMPDIR:-/tmp}/update-venv" # 临时 venv 基目录
RETRY_MAX=3                                 # 每条命令的重试次数
SLEEP_BETWEEN_RETRIES=2
VERBOSE=true # true 会把命令输出到控制台并写日志；false 则只写日志

# 颜色（用于终端显示）
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
RED="\033[0;31m"
BLUE="\033[0;34m"
BOLD="\033[1m"
RESET="\033[0m"

timestamp() { date '+%Y-%m-%d %H:%M:%S'; }

log() {
  local msg="$1"
  echo -e "$(timestamp) ${msg}" | tee -a "$LOG_FILE"
}

# -------------------------
# 模式判断
# -------------------------
should_run() {
  local section="$1"
  [[ "$MODE" == "all" || "$MODE" == "$section" ]]
}

# -------------------------
# 执行带重试的命令（捕获 stderr），并可检测特定错误文本
# 1) cmd (字符串) - 要执行的命令
# 2) allowed_error_pattern (可选) - 如果 stderr 包含此 pattern，则视为“可忽略的错误”并返回 0
# 返回：0 成功（或被允许的错误），非0 失败
# -------------------------
run_with_retry() {
  local cmd="$1"
  local allowed_pattern="${2:-}"
  local attempt=1
  local outfile
  outfile="$(mktemp)"
  while [ $attempt -le $RETRY_MAX ]; do
    if $VERBOSE; then
      # - 显示命令开始
      log "${BLUE}▶ 执行: ${cmd}${RESET}"
      # 执行并把 stdout/stderr 同时写到临时文件
      bash -lc "$cmd" >"$outfile" 2>&1 && {
        cat "$outfile" | tee -a "$LOG_FILE"
        rm -f "$outfile"
        return 0
      }
      # 失败则打印输出并判断
      cat "$outfile" | tee -a "$LOG_FILE"
    else
      bash -lc "$cmd" >"$outfile" 2>&1 || true
    fi

    # 读取 stderr/stdout 做判断
    local out
    out="$(cat "$outfile")"

    # 如果允许特定错误模式（例如 Homebrew cask conflicts），则当匹配时返回成功（视同忽略）
    if [ -n "$allowed_pattern" ] && printf "%s" "$out" | grep -qiE "$allowed_pattern"; then
      log "${YELLOW}⚠️ 检测到可忽略错误（匹配模式: $allowed_pattern），将跳过该错误。输出片段：${RESET}"
      printf "%s\n" "$out" | sed -n '1,80p' | tee -a "$LOG_FILE"
      rm -f "$outfile"
      return 0
    fi

    # 如果未匹配允许模式，则重试或失败
    log "${YELLOW}⚠️ 尝试 ${attempt}/${RETRY_MAX} 失败，命令: ${cmd}${RESET}"
    ((attempt++))
    sleep "$SLEEP_BETWEEN_RETRIES"
  done

  log "${RED}❌ 最终失败: ${cmd}${RESET}"
  printf "%s\n" "$(cat "$outfile" | sed -n '1,200p')" >>"$LOG_FILE" || true
  rm -f "$outfile"
  return 1
}

# -------------------------
# Homebrew 特殊升级包装：对可能出错的 cask 升级做容错
# 识别 "conflicts_with" 或 "Calling conflicts_with" 的报错并忽略
# -------------------------
brew_safe_upgrade() {
  # 先 update，再 upgrade
  if command -v brew &>/dev/null; then
    run_with_retry "brew update" || true
    # upgrade 可能输出某些 Cask 错误，允许包含 conflicts_with 之类的文本并继续
    run_with_retry "brew upgrade" "conflicts_with|Calling conflicts_with|is disabled" || true
    run_with_retry "brew cleanup -s" || true
    run_with_retry "brew autoremove" || true
    log "${GREEN}✅ Homebrew 更新与清理完成${RESET}"
  else
    log "${YELLOW}⚠️ Homebrew 未安装，跳过${RESET}"
  fi
}

# -------------------------
# pip 安全升级策略：
# 1) 尝试使用 --user 升级 pip/setuptools/wheel
# 2) 如果被 PEP 668 拒绝（externally-managed-environment），则在临时 venv 中执行升级并使用 venv 的 pip 来更新包或安装用户包
# 3) 升级包时跳过 editable / 本地包
# -------------------------
python_safe_upgrade() {
  if ! command -v python3 &>/dev/null; then
    log "${YELLOW}⚠️ python3 未安装，跳过 Python 更新${RESET}"
    return 0
  fi

  log "${BLUE}🐍 开始 Python 包更新（安全模式）...${RESET}"

  # 升级 pip/setuptools/wheel 尝试 --user（更安全）
  log "▶ 尝试使用 'pip3 install --upgrade pip setuptools wheel --user'（推荐）"
  # 把 stderr 收集，判断是否含有 PEP668 报错
  local tmpout
  tmpout="$(mktemp)"
  if pip3 install --upgrade pip setuptools wheel --user >"$tmpout" 2>&1; then
    cat "$tmpout" | tee -a "$LOG_FILE"
    rm -f "$tmpout"
    log "${GREEN}✅ pip & setuptools & wheel 已使用 --user 升级（或已是最新）${RESET}"
  else
    # 捕获错误内容，判断是否是 externall-managed-environment
    local err
    err="$(cat "$tmpout")"
    echo "$err" | tee -a "$LOG_FILE"
    rm -f "$tmpout"
    if printf "%s" "$err" | grep -qi "externally-managed-environment\|This environment is externally managed"; then
      log "${YELLOW}⚠️ 检测到 PEP 668 保护，无法直接系统级升级 pip。将使用临时 venv 回退策略。${RESET}"
      python_safe_upgrade_with_venv
    else
      log "${YELLOW}⚠️ pip 升级失败（非 PEP 668），将尝试使用 --user 作为回退，并继续升级包。${RESET}"
      # 再次强制用 --user（已经试过但保险起见）
      run_with_retry "pip3 install --upgrade pip setuptools wheel --user" || true
    fi
  fi

  # 现在列出 pip 包并尝试升级（跳过 editable 与本地包）
  log "▶ 列出并逐个升级 pip 包（跳过 editable / 本地包）"
  # 获取包名列表（不包括 pip 自身）
  local packages
  packages="$(python3 -m pip list --format=freeze 2>/dev/null | cut -d'=' -f1 | grep -v -E '^pip$' || true)"
  if [ -z "$packages" ]; then
    log "${YELLOW}⚠️ 未发现可升级的 pip 包${RESET}"
    return 0
  fi

  for pkg in $packages; do
    # 跳过 uv 管理或其他特殊包的逻辑可在此扩展（当前不自动处理 uv）
    # 跳过 editable 本地包
    if python3 -m pip show "$pkg" 2>/dev/null | grep -qi "Location:.*egg-info\|Editable project"; then
      log "${YELLOW}⏭ 跳过本地或 editable 包: ${pkg}${RESET}"
      continue
    fi
    # 使用 --user 安全升级（会安装到 ~/.local 或者对应用户 site）
    log "▶ 升级：python3 -m pip install --upgrade --user ${pkg}"
    run_with_retry "python3 -m pip install --upgrade --user \"${pkg}\"" || log "${YELLOW}⚠️ 升级 ${pkg} 失败，已记录${RESET}"
  done

  # 清理 pip 缓存（失败则忽略）
  python3 -m pip cache purge 2>/dev/null || true
  log "${GREEN}✅ Python 包更新完成（使用用户/venv 安全策略）${RESET}"
}

# 当系统拒绝直接升级 pip 时，使用临时 venv 回退
python_safe_upgrade_with_venv() {
  # 创建临时 venv
  local venv="${TMP_VENV_BASE}-$$"
  log "▶ 创建临时 venv: ${venv}"
  python3 -m venv "$venv"
  # 激活并升级 pip 等
  # 注意：在子 shell 中执行，避免污染当前 shell
  (
    set -e
    source "${venv}/bin/activate"
    python -m pip install --upgrade pip setuptools wheel
    # 升级完毕后（可选）用 venv 的 pip 来执行其他全局命令或导出工具
  )
  # 删除临时 venv
  rm -rf "$venv"
  log "${GREEN}✅ 临时 venv 升级 pip 完成并已移除${RESET}"
}

# -------------------------
# npm / yarn / bun 更新函数（尽量保持原有行为）
# -------------------------
npm_update() {
  if command -v npm &>/dev/null; then
    log "${BLUE}📦 更新 npm 全局包并清理缓存...${RESET}"
    run_with_retry "npm update -g" || true
    run_with_retry "npm cache clean --force" || true
    log "${GREEN}✅ npm 更新完成${RESET}"
  else
    log "${YELLOW}⚠️ 未安装 npm，跳过${RESET}"
  fi
}

yarn_update() {
  if command -v yarn &>/dev/null; then
    log "${BLUE}🧶 更新 yarn（Corepack 激活）...${RESET}"
    run_with_retry "corepack prepare yarn@stable --activate" || true
    run_with_retry "yarn cache clean" || true
    log "${GREEN}✅ yarn 更新完成${RESET}"
  else
    log "${YELLOW}⚠️ 未安装 yarn，跳过${RESET}"
  fi
}

bun_update() {
  if command -v bun &>/dev/null; then
    log "${BLUE}🥯 更新 bun...${RESET}"
    run_with_retry "bun upgrade" || true
    run_with_retry "bun pm cache clean" || true
    log "${GREEN}✅ bun 更新完成${RESET}"
  else
    log "${YELLOW}⚠️ 未安装 bun，跳过${RESET}"
  fi
}

# -------------------------
# Rust / Cargo 更新
# -------------------------
rust_update() {
  if command -v rustup &>/dev/null; then
    log "${BLUE}🦀 更新 rustup & toolchains...${RESET}"
    run_with_retry "rustup update" || true
    log "${GREEN}✅ rustup 更新完成${RESET}"
  else
    log "${YELLOW}⚠️ 未检测到 rustup，跳过 Rust 更新${RESET}"
  fi

  if command -v cargo &>/dev/null; then
    # 如果 cargo-install-update 未安装，提示安装但不强制
    if cargo install-update --help &>/dev/null 2>&1; then
      log "${BLUE}▶ 使用 cargo-install-update 升级 cargo 包...${RESET}"
      run_with_retry "cargo install-update -a" || true
      log "${GREEN}✅ cargo 包更新完成${RESET}"
    else
      log "${YELLOW}⚠️ cargo-install-update 未安装，若需升级 cargo 包请安装 cargo-install-update${RESET}"
    fi
  fi
}

# -------------------------
# Git 仓库更新（保留你的原逻辑并增强）
# -------------------------
git_update() {
  if [ ! -f "$GIT_CONF" ]; then
    log "${YELLOW}⚠️ 未找到 Git 配置文件: $GIT_CONF，创建示例文件${RESET}"
    cat >"$GIT_CONF" <<'EOF'
# Git 仓库配置示例
# 支持两种格式：
# 1) 本地仓库路径
# /Users/you/Projects/myrepo
# 2) 克隆格式: 源URL -> 目标路径
# https://github.com/user/repo.git -> ~/Projects/repo
EOF
    log "请编辑 $GIT_CONF 后再次运行脚本（示例已写入）"
    return 0
  fi

  log "${BLUE}🌀 开始按配置更新 Git 仓库...${RESET}"
  local SUCCESS_COUNT=0 SKIP_COUNT=0 FAIL_COUNT=0

  # 逐行读取
  while IFS= read -r raw || [ -n "$raw" ]; do
    # 移除注释与前后空白
    local line
    line="$(printf "%s" "$raw" | sed 's/#.*$//' | xargs || true)"
    [ -z "$line" ] && continue

    log "🔄 处理: ${line}"
    local src dest repo

    if [[ "$line" == *"->"* ]]; then
      src="$(printf "%s" "$line" | awk -F'->' '{print $1}' | xargs)"
      dest="$(printf "%s" "$line" | awk -F'->' '{print $2}' | xargs)"
      dest="$(eval echo "$dest")"
      if [ ! -d "$dest/.git" ]; then
        log "🚧 克隆新仓库: $src -> $dest"
        if git clone "$src" "$dest" >>"$LOG_FILE" 2>&1; then
          log "${GREEN}✅ 克隆成功: ${dest}${RESET}"
          ((SUCCESS_COUNT++))
        else
          log "${RED}❌ 克隆失败: ${dest}${RESET}"
          ((FAIL_COUNT++))
        fi
        continue
      else
        repo="$dest"
      fi
    else
      repo="$(eval echo "$line")"
    fi

    if [ ! -d "$repo/.git" ]; then
      log "${YELLOW}⏭ 跳过 ${repo}（非 Git 仓库）${RESET}"
      ((SKIP_COUNT++))
      continue
    fi

    # 进入仓库并检查未提交改动
    pushd "$repo" >/dev/null || {
      log "${RED}无法进入 $repo${RESET}"
      ((FAIL_COUNT++))
      continue
    }
    if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
      log "${YELLOW}⏭ 跳过 ${repo}（存在未提交改动）${RESET}"
      ((SKIP_COUNT++))
      popd >/dev/null
      continue
    fi

    if git pull --rebase --autostash >>"$LOG_FILE" 2>&1; then
      log "${GREEN}✅ 成功更新 ${repo}${RESET}"
      ((SUCCESS_COUNT++))
    else
      log "${RED}❌ 更新失败 ${repo}（已记录）${RESET}"
      ((FAIL_COUNT++))
    fi
    popd >/dev/null
  done <"$GIT_CONF"

  log "${BLUE}📊 Git 更新统计: 成功=${SUCCESS_COUNT} 跳过=${SKIP_COUNT} 失败=${FAIL_COUNT}${RESET}"
}

# -------------------------
# 主流程
# -------------------------
START_TIME=$(date +%s)
{
  echo "=============================================="
  echo "🧩 开始更新: $(timestamp)"
  echo "模式: $MODE"
  echo "日志: $LOG_FILE"
  echo "=============================================="
} | tee -a "$LOG_FILE"

if should_run system; then
  log "${BOLD}${BLUE}🧠 [系统模块] 更新系统包管理器...${RESET}"
  brew_safe_upgrade

  npm_update
  yarn_update
  bun_update

  # Python 安全更新
  python_safe_upgrade

  # Rust / cargo
  rust_update

  log "${GREEN}🎉 系统模块更新完成${RESET}"
fi

if should_run git; then
  git_update
fi

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
log "${BOLD}${GREEN}🎉 全部任务完成（用时 ${DURATION} 秒）${RESET}"
log "查看完整日志： tail -n 200 ${LOG_FILE}"

exit 0
