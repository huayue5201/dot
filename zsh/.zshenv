
. "$HOME/.cargo/env"

# https://bun.sh/
export PATH="$HOME/.bun/bin:$PATH"

# 设置默认编辑器为 Neovim
export PATH="$PATH:$HOME/Downloads/nvim-macos-arm64/bin"
export EDITOR=nvim
export VISUAL=nvim

# 设置代理（适用于 VPS 环境）
export http_proxy=http://127.0.0.1:2080
export https_proxy=$http_proxy

# 设置 LLVM 路径
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

# 设置 Homebrew 和其他工具的路径
export PATH="/opt/homebrew/bin:$PATH"
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"
export PATH="/opt/homebrew/Cellar/gcc/13.2.0/bin:$PATH"
export PATH="$PATH:$HOME/.local/bin"

# ========================================
# STM32Cube 路径配置（适用于 STM32 编程）
# ========================================
export STM32CubeMX_PATH=/Applications/STMicroelectronics/STM32CubeMX.app/Contents/Resources
export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin
