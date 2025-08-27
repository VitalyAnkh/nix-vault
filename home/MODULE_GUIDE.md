# Home-Manager 模块完整指南

## 目录结构概览

```
home/
├── base/           # 基础模块（跨平台）
│   ├── core/       # 核心配置
│   ├── gui/        # GUI 应用
│   └── tui/        # TUI 工具
├── linux/          # Linux 特定
└── darwin/         # macOS 特定
```

## 详细模块列表

### 1. 核心模块 (home/base/core/)

#### home/base/core/default.nix
- **作用**: 自动导入 core 目录下所有模块
- **包含**: btop, core, editors, git, npm, pip, shells, starship, theme, yazi, zellij

#### home/base/core/core.nix
- **作用**: 基础系统工具和配置
- **包含**: 
  - 基础工具: bat, eza, fzf, zoxide
  - 开发工具: delta, lazygit, tokei
  - 系统工具: duf, gdu, fd, ripgrep

#### home/base/core/btop.nix
- **作用**: btop 系统监控工具配置
- **特点**: 带 catppuccin 主题

#### home/base/core/git.nix
- **作用**: Git 版本控制配置
- **包含**: 
  - 用户信息配置
  - delta diff 工具
  - 常用别名
  - pull.rebase = true

#### home/base/core/npm.nix
- **作用**: Node.js 和 npm 配置
- **包含**: nodejs, pnpm, yarn, bun

#### home/base/core/pip.nix
- **作用**: Python pip 配置
- **设置**: 使用清华镜像源

#### home/base/core/shells/
- **作用**: Shell 配置
- **包含**: bash, fish, nushell 配置

#### home/base/core/starship.nix
- **作用**: Starship 终端提示符
- **特点**: 带 catppuccin 主题

#### home/base/core/theme.nix
- **作用**: Catppuccin 主题配置
- **应用**: 全局主题设置

#### home/base/core/yazi.nix
- **作用**: Yazi 文件管理器
- **特点**: 带主题配置

#### home/base/core/zellij/
- **作用**: Zellij 终端复用器
- **特点**: 自定义配置和键绑定

#### home/base/core/editors/
- **包含**: helix, neovim 基础配置

### 2. TUI 模块 (home/base/tui/)

#### home/base/tui/default.nix
- **作用**: 自动导入所有 TUI 相关模块

#### home/base/tui/container.nix
- **作用**: 容器和 Kubernetes 工具
- **包含**:
  - 容器工具: podman-compose, dive, lazydocker, skopeo
  - K8s 工具: kubectl, kubectx, k9s, helm, flux, argocd
  - 构建工具: ko, kubebuilder

#### home/base/tui/dev-tools.nix
- **作用**: 开发工具集
- **包含**:
  - 语言: gcc, go, rustup, python3, ruby
  - 工具: cmake, gnumake, ninja
  - 调试: gdb, lldb, valgrind
  - 分析: hyperfine, flamegraph

#### home/base/tui/cloud/
- **作用**: 云服务工具
- **包含**: awscli2, azure-cli, google-cloud-sdk, terraform, ansible

#### home/base/tui/editors/
- **包含**: 
  - emacs (带 doom 配置)
  - helix (高级配置)
  - neovim (AstroNvim 配置)

#### home/base/tui/encryption/
- **作用**: 加密工具
- **包含**: age, sops

#### home/base/tui/gpg/
- **作用**: GPG 配置
- **设置**: 密钥服务器、缓存时间

#### home/base/tui/password-store/
- **作用**: pass 密码管理器
- **包含**: pass, passExtensions

#### home/base/tui/shell.nix
- **作用**: Shell 增强工具
- **包含**: atuin (历史搜索), mcfly, zellij

#### home/base/tui/ssh.nix
- **作用**: SSH 客户端配置
- **设置**: ControlMaster, 压缩等

### 3. GUI 模块 (home/base/gui/)

#### home/base/gui/default.nix
- **作用**: 自动导入所有 GUI 模块

#### home/base/gui/academia.nix
- **作用**: 学术工具
- **包含**: zotero, obsidian, anki

#### home/base/gui/dev-tools.nix
- **作用**: GUI 开发工具
- **包含**:
  - 工具: mitmproxy, wireshark, jetbrains-toolbox
  - AI: k8sgpt, kubectl-ai
  - 其他: nvfetcher, ninja, uv

#### home/base/gui/games.nix
- **作用**: 游戏相关
- **包含**: steam, bottles, gamemode

#### home/base/gui/media.nix
- **作用**: 多媒体软件
- **包含**:
  - 音视频: vlc, mpv, spotify
  - 图像: gimp, inkscape
  - 录制: obs-studio

#### home/base/gui/terminal/
- **作用**: 终端模拟器
- **包含**: alacritty, kitty, foot, warp, ghostty

### 4. Linux 特定模块 (home/linux/)

#### home/linux/base/
- **作用**: Linux 基础配置
- **包含**:
  - shell.nix: Linux 特定 shell 配置
  - tools.nix: Linux 工具

#### home/linux/gui.nix
- **作用**: Linux GUI 配置集合
- **导入**:
  - home/base/gui
  - home/linux/gui/base
  - home/linux/gui/editors

#### home/linux/gui/base/
- **包含**:
  - creative.nix: 创意工具 (blender, krita)
  - fcitx5/: 输入法配置
  - games.nix: Linux 游戏工具
  - gtk.nix: GTK 主题配置
  - media.nix: 媒体工具
  - note-taking.nix: 笔记工具
  - wallpaper/: 壁纸管理
  - xdg.nix: XDG 配置

#### home/linux/gui/hyprland/
- **作用**: Hyprland 窗口管理器
- **包含**: 完整的 hyprland 配置、waybar、mako 等

### 5. 基础配置 (home/base/home.nix)
- **作用**: Home-Manager 基础设置
- **内容**: username, stateVersion

## 使用示例

### 最小配置（仅核心工具）
```nix
home-modules = [
  "home/base/core"
  "home/base/home.nix"
];
```

### 服务器配置（TUI 工具）
```nix
home-modules = [
  "home/base/core"
  "home/base/tui"
  "home/linux/base"
  "home/base/home.nix"
];
```

### 开发工作站（带 GUI）
```nix
home-modules = [
  "home/base/core"
  "home/base/tui"
  "home/base/gui"
  "home/linux/base"
  "home/linux/gui.nix"
  "home/base/home.nix"
];
```

### Kubernetes 开发环境
```nix
home-modules = [
  "home/base/core"
  "home/base/tui/container.nix"  # 只要容器工具
  "home/base/tui/cloud"          # 云工具
  "home/linux/base"
];
```

### 创意工作站
```nix
home-modules = [
  "home/base/core"
  "home/base/gui"
  "home/linux/gui/base/creative.nix"
  "home/linux/gui/base/media.nix"
];
```

## 模块选择建议

### 按用途选择

**基础系统** (必选):
- `home/base/core` - 核心工具
- `home/base/home.nix` - 基础配置

**开发环境**:
- `home/base/tui/dev-tools.nix` - 开发工具
- `home/base/tui/editors/` - 编辑器
- `home/base/core/git.nix` - 版本控制

**容器/K8s**:
- `home/base/tui/container.nix` - 容器工具
- `home/base/tui/cloud/` - 云服务

**桌面环境**:
- `home/base/gui` - GUI 应用
- `home/linux/gui/hyprland/` - Hyprland WM

**多媒体创作**:
- `home/linux/gui/base/creative.nix` - 创意工具
- `home/base/gui/media.nix` - 媒体软件

### 按系统类型

**低配服务器/VPS**:
```nix
[
  "home/base/core/core.nix"      # 最基础工具
  "home/base/core/git.nix"       # Git
  "home/base/core/shells"        # Shell
  "home/base/tui/ssh.nix"        # SSH
]
```

**标准服务器**:
```nix
[
  "home/base/core"
  "home/base/tui"
  "home/linux/base"
]
```

**工作站**:
```nix
[
  "home/base/core"
  "home/base/tui"
  "home/base/gui"
  "home/linux/gui.nix"
]
```

## 注意事项

1. **模块依赖**: 
   - `home/linux/gui.nix` 会自动导入 `home/base/gui`
   - 各目录的 `default.nix` 会自动导入该目录下所有模块

2. **平台兼容性**:
   - `home/base/` - 跨平台
   - `home/linux/` - Linux 专用
   - `home/darwin/` - macOS 专用

3. **性能考虑**:
   - 低配系统避免导入 `home/base/gui`
   - 容器环境只导入必要的 `core` 模块

4. **主题一致性**:
   - `home/base/core/theme.nix` 提供统一的 Catppuccin 主题
   - 大多数工具已配置主题集成

## 当前 revachol 配置分析

revachol 当前导入了:
- ✅ `home/base/core`
- ✅ `home/base/tui`
- ✅ `home/linux/base`
- ❌ `home/base/gui` (桌面版本才有)
- ❌ `home/base/home.nix` (可能需要添加)

建议: revachol 的配置已经比较完整，如果需要可以考虑添加 `home/base/home.nix` 以确保基础配置完整。