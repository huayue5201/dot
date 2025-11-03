# Cargo
. "$HOME/.cargo/env"

# Bun
export PATH="$HOME/.bun/bin:$PATH"

# Homebrew & Python & LLVM & GCC
export PATH="/opt/homebrew/opt/python@3.14/libexec/bin:/opt/homebrew/opt/llvm/bin:/opt/homebrew/Cellar/gcc/13.2.0/bin:/opt/homebrew/bin:$PATH"

# Neovim
export PATH="$PATH:$HOME/Downloads/nvim-macos-arm64/bin"

# Local bin
export PATH="$PATH:$HOME/.local/bin"

# 编辑器
export EDITOR=nvim
export VISUAL=nvim

# LLVM flags
export LDFLAGS="-L/opt/homebrew/opt/llvm/lib"
export CPPFLAGS="-I/opt/homebrew/opt/llvm/include"

# 代理
export http_proxy=http://127.0.0.1:2080
export https_proxy=$http_proxy

# STM32Cube 路径
export STM32CubeMX_PATH=/Applications/STMicroelectronics/STM32CubeMX.app/Contents/Resources
export STM32_PRG_PATH=/Applications/STMicroelectronics/STM32Cube/STM32CubeProgrammer/STM32CubeProgrammer.app/Contents/MacOs/bin
