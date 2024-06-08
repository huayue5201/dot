#!/bin/bash

# to maintain cask ....
#     brew update && brew cleanup

# 基本工具
brew install stow # dotfile管理
cd ~/dotfile
stow git
stow nvim
stow alacritty
stow btop
stow tmux
stow aria2
stow gitui
brew install git
brew install difftastic # git diff语义增强
brew install gitui # git管理GUI
brew install fzf
brew install fd
brew install ripgrep # rg
brew install bat # cat替代
brew install btop # 系统监测
brew install tmux # 终端复用
brew install aria2 # 下载工具
brew install --HEAD neovim
brew install libgit2 # neovim SuperBo/fugit2.nvim插件依赖
brew install yazi
brew install pipx # python虚拟环境管理工具
brew install xray # 作为后台启动:brew services start xray
brew install llvm
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh # 安装rust
brew install lsusb # usb设备查看工具

# mcu 开发环境
brew install --cask gcc-arm-embedded #gcc交叉编译工具
brew install openocd # debug.烧录工具
brew install telnet # openocd依赖
pipx install compiledb # compile_commands.json生成工具 compiledb make
brew install node

# brew 命令扩展
brew tap buo/cask-upgrade # cask更新 brew cu [CASK name]
brew tap beeftornado/rmtre # 删除包及其依赖 brew rmtre [packge neme]

# cask
brew install orbstack # docker和linux虚拟机
brew install alacritty # 终端
brew tap homebrew/cask-fonts # fonts字体安装
brew install --cask font-fira-code-nerd-font
brew install --cask font-victor-mono-nerd-font
brew install --cask font-gohufont-nerd-font
brew install --cask font-anonymice-nerd-font
