{ config, pkgs, ... }:

{
# Home Manager 需要一些关于你和它应该管理的路径的信息。
   home.username = "lijia";
   home.homeDirectory = "/Users/lijia";

# 这个值确定你的配置与 Home Manager 发布版的兼容性。这有助于避免在新的 Home Manager 发布版引入不兼容的变更时出现故障。
#
# 你不应该更改这个值，即使你更新了 Home Manager。如果你确实想更新该值，请确保首先查阅 Home Manager 发布说明。
   home.stateVersion = "23.11"; # 请在更改之前阅读注释。

# home.packages 选项允许你在环境中安装 Nix 软件包。
      home.packages = [
# # 将 'hello' 命令添加到你的环境中。当运行时，它会友好地打印 "Hello, world!"。
# pkgs.hello

# # 有时候，对软件包进行细微调整很有用，例如，通过应用覆盖。你可以直接在这里进行，只要不要忘记括号。也许你想要使用有限数量的字体安装 Nerd Fonts？
# (pkgs.nerdfonts.override { fonts = [ "FantasqueSansMono" ]; })

# # 你还可以直接在配置文件中创建简单的 shell 脚本。例如，这会在你的环境中添加一个名为 'my-hello' 的命令：
# (pkgs.writeShellScriptBin "my-hello" ''
#   echo "Hello, ${config.home.username}!"
# '')
      ];

# Home Manager 非常擅长管理 dotfiles。管理普通文件的主要方式是通过 'home.file'。
   home.file = {
# # 构建此配置将在 Nix 存储中创建 'dotfiles/screenrc' 的副本。激活配置将使 '~/.screenrc' 成为指向 Nix 存储副本的符号链接。
# ".screenrc".source = dotfiles/screenrc;

# # 你也可以立即设置文件内容。
# ".gradle/gradle.properties".text = ''
#   org.gradle.console=verbose
#   org.gradle.daemon.idletimeout=3600000
# '';
   };

# Home Manager 还可以通过 'home.sessionVariables' 管理你的环境变量。如果你不想通过 Home Manager 管理你的 shell，那么你必须手动在以下位置之一源化 'hm-session-vars.sh'：
#
#  ~/.nix-profile/etc/profile.d/hm-session-vars.sh
#
# 或
#
#  ~/.local/state/nix/profiles/profile/etc/profile.d/hm-session-vars.sh
#
# 或
#
#  /etc/profiles/per-user/lijia/etc/profile.d/hm-session-vars.sh
#
   home.sessionVariables = {
# EDITOR = "emacs";
   };

# 让 Home Manager 安装和管理自己。
   programs.home-manager.enable = true;
}
