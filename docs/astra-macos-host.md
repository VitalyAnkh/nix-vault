# astra macOS host

`astra` 是 Apple Silicon macOS 主机，通过 `darwinConfigurations.astra`
同时部署 nix-darwin 与集成 Home Manager。账号名取自私有输入 `mysecrets` 的
`hosts/astra/account.nix`，公开仓库中不写出；家目录为 `/Users/<账号>`，时区为
`Asia/Singapore`。配置使用仓库固定的 inputs 和 `pkgs/` 包管线。

## 配置入口

| 文件                                   | 职责                                                                                    |
| -------------------------------------- | --------------------------------------------------------------------------------------- |
| `outputs/aarch64-darwin/src/astra.nix` | 注册主机、声明账号和仓库路径、向系统及 HM 传入相同主机变量                              |
| `hosts/darwin-astra/default.nix`       | 主机名、Nix 托管、系统 shell、PAM、字体及 OpenLDAP 来源                                 |
| `hosts/darwin-astra/homebrew.nix`      | Homebrew 软件清单、激活时的 Homebrew 行为及镜像设置                                     |
| `home/hosts/darwin/darwin-astra.nix`   | HM 工作环境及本机选择                                                                   |
| `modules/darwin/overlays.nix`          | 所有 Darwin 主机共用：仅构建期使用 Node 的包复用上游构建、Jeepney 测试修复              |
| `modules/darwin/nix-daemon.nix`        | 所有 Darwin 主机共用：nix-darwin 管理 Nix 时，daemon 日志写入 `/var/log/nix-daemon.log` |
| `modules/darwin/system-paths.nix`      | 所有 Darwin 主机共用：在 Nix 路径之后补回 `/etc/paths`、`/etc/paths.d` 中的目录         |
| `home/darwin`、`home/base`             | 与 `fern`、`frieren` 共用的编辑器、shell、开发工具和应用配置                            |

主机级 `repoRoot` 为家目录下的 `projects/dev/nix/nix-vault`。仓库位置改变时更新该值；`j`（即
`just -f <repoRoot>/justfile`）、项目模板命令以及启用后的 AeroSpace/proxy 配置使用此路径。

astra 只在 `outputs/aarch64-darwin/src/astra.nix` 中覆盖 `myvars`
的账号和仓库路径；其它主机和独立 HM 输出使用全局
`myvars`。astra 的 HM 随 nix-darwin 激活，不另设管理同一家目录的独立 HM output。

## 主机策略

- nix-darwin 托管 Nix、daemon 与 Nix 设置，使用共享缓存配置；daemon 日志写入
  `/var/log/nix-daemon.log`，自动 GC 和 store 优化关闭。
- Home Manager 集成在 nix-darwin 中，复用共享 macOS 开发环境。
- Nix 声明 Homebrew 的软件清单，Homebrew 负责安装和更新；激活只补装缺少的包，不升级、不卸载（见“Homebrew”一节）。Zotero 和 Obsidian 来自 Homebrew
  cask，HM 不另装一份（`modules.desktop.academia.enable = false`）。
- 保留当前 macOS 桌面及 AeroSpace/proxy 应用配置；不导入共享系统 defaults。
- 输入法沿用 macOS 自带的 ABC 和简体中文双拼（不安装 Squirrel，也不生成
  `~/Library/Rime`），用 Ctrl+Shift+8（“选择上一个输入法”）切换。macOS 只有一个全局的当前输入法，在一个 App 里切到中文后，其他 App 也是中文；因此由
  [Input Source Pro](../home/darwin/input-source-pro/default.nix)（cask
  `input-source-pro`）在任一 App 切到前台时选回 ABC。它从不自己选择双拼，所以不需要辅助功能或输入监控权限，也不要开启它的“增强模式”和“修复输入法切换问题”。输入法按 App 而非按窗口切换：回到刚输入过中文的 App 也是 ABC。偏好由 HM 写入
  `com.runjuu.Input-Source-Pro`，修改后需重启该 App；它每次启动会向 inputsource.pro 报告版本号。
- 键位由 [Karabiner 模块](../home/darwin/karabiner/README.md) 管理：所有键盘交换 Caps
  Lock 与左 Control；内置键盘还交换 Command 与 Option，使空格旁的键成为 Option（左侧的在 Emacs 中是 Meta），与 Linux 下 PC 键盘的 Alt 位置相同；限定应用另有 Linux 风格的快捷键。Native
  profile 保留这两种交换。Karabiner 接管的键盘不使用 macOS 修饰键设置，因此这些交换只在 Karabiner 中声明。
- Ctrl+Shift+Q（物理 Caps Lock+Shift+Q）在任何 App 中切换 Emacs：Emacs 不在前台时打开 HM 复制的
  `~/Applications/Home Manager Apps/Emacs.app`，未运行则启动；Emacs 在前台时发送 ⌘H 隐藏它，回到之前的 App。两个 Nix
  Vault profile 都生效，随激活时的 Karabiner 同步生效；限制与验证方法见
  [Karabiner 模块](../home/darwin/karabiner/README.md#emacs-hotkey)。
- 用户的 `~/.ssh/config` 和客户端身份保持用户管理，包括 Colima 的 Include。
- Git 的通用工具与配置由 HM 提供；姓名、邮箱、签名和个人 include 保留在用户自己的配置中。HM 不删除
  `~/.gitconfig`，也不向 astra 注入其他主机使用者的 Git 身份。
- GPG 密钥与信任库保持可写，Pass 不指定原作者的加密/签名密钥。
- 不管理 `/etc/pam.d/sudo_local`：macOS 的 `/etc/pam.d/sudo`
  已 include 它，nix-darwin 在此生成的内容为空。需要 Touch ID sudo 时，同时启用
  `security.pam.services.sudo_local.enable` 和 `touchIdAuth`。
- 不导入 agenix secrets，也不从 Nushell 注入工作私有 alias 或替换 AI
  provider。凭据不得写入 Nix 表达式、Nix store 或构建日志。

这些是 astra 的正常主机选择。需要改变应用接管范围时，修改对应能力选项并重新验证产物。AeroSpace、Squirrel 等能力的配置和应用本体须同时就绪，生成配置文件不等于安装了应用。

### Emacs

`modules.editors.emacs.enable = true` 安装仓库的原生 Emacs
`pkgs.emacs-master-pgtk-with-igc`。属性名中的 PGTK 指 Linux 上的构建；在 Darwin 上它构建 NS（Cocoa/AppKit）版本（pname
`emacs-master-ns-with-igc`），保留 IGC 和原生编译。

`modules.editors.emacs.doom.enable` 使用默认值 `true`：安装 Doom 依赖，把 `flake.lock`
固定的 Doom 源码同步到 `~/.config/emacs`，把 `~/.config/doom` 链接到配置仓库
`~/projects/dev/emacs-projects/doom`，并让 Bash、Zsh 和 Fish 找到 `doom`
命令。Doom 的模块（`:ui`、`:lang` 等）在 git 子模块 `sources/doom+`
中，GitHub 的 tarball 不包含子模块，所以 `doomemacs`
输入以带子模块的 git 方式获取；缺少模块时 Doom 只加载核心部分，`init.el` 中启用的模块都不生效。

- `~/.emacs.d`、`~/.emacs` 或 `~/.emacs.el` 存在时，Emacs 从它们启动，不读取
  `~/.config/emacs`。Doom 安装前运行过的 Emacs 会创建空的
  `~/.emacs.d`：激活时删除空目录，其他情况给出警告。
- Doom 的配置文件中只有 `config.org` 受版本控制，`init.el`、`config.el`、`packages.el`
  等由它生成。新机器上先完整 tangle 一次（配置仓库的 `just doom`），再运行 `doom sync`；之后
  `doom sync` 在同步前自动完整 tangle。
- 从 Dock、Spotlight 或快捷键启动的 GUI
  Emacs 继承 launchd 的环境，没有 shell 的 PATH。`doom sync --env` 生成环境变量文件
  `~/.config/emacs/.local/etc/init.d/05-doom-env.load.el`，Doom 启动时读取；该文件存在后，每次
  `doom sync` 都把运行它的进程的环境变量（`doom-env-deny`
  排除的除外）重新写入该文件。因此在终端的新登录 shell 中运行
  `doom sync`，不要在 agent 等带有额外变量（例如令牌）的进程中运行，否则这些变量会写入该文件。`doom sync --no-env`
  删除该文件。
- astra 所在网络经常连不上 GitHub 的 HTTPS，SSH 则可用。Doom 以 `DOOMGITCONFIG` 指向的文件作为
  `doom sync` 中 git 命令的全局配置，astra 的这个文件把 `https://github.com/` 改写为
  `git@github.com:`，因此 Doom 克隆和更新 GitHub 上的包时走 SSH，需要可用的 SSH 密钥；其他程序的 git 配置不受影响。
- Doom 配置不固定 straight.el 的版本，Emacs 模块因此给复制的 Doom 源码打补丁，使 Doom 能读取 straight.el 构建缓存中带最低版本的依赖记录；否则
  `doom sync` 报 `(wrong-type-argument listp "9.7")`。
- `pkgs/emacs` 补回 IGC 分支缺少的 bug#81906 上游修复，否则所有 `doom` 命令都报
  `cl-assertion-failed: ((> (point) output-start))`；在 Darwin 上它还带有读取辅助功能文本的本地修复。这些补丁的原因与移除条件见
  [Emacs 模块说明](../home/base/tui/editors/emacs/README.md)。

`modules.editors.emacs.daemon.enable = false`：使用普通 GUI 启动，不自动接管用户 Emacs
daemon；Emacs 全局快捷键打开的是 `Emacs.app`。可用 `emacs -Q` 验证纯净启动。

### Shell 环境

Zsh 使用 `~/.config/zsh`。Bash、Zsh 和 Fish 的环境通过 Home Manager 的 `home.sessionPath` /
`home.sessionVariables` 统一声明；Fish 使用 HM 原生生成的环境脚本。各 shell 继续复用共享的
`shellAliases`。

Starship 提示符在行首显示
`用户@主机`（Starship 默认只在 SSH 中显示二者），然后是目录和 kubectl 的当前 context。共享设置把 context 放在行首并接
`in`，看起来像用户名，GKE 的 context 名又很长；astra 把它移到目录之后，`gke_<项目>_<区域>_<集群>`
只显示集群名。

PATH 的顺序与来源：

- HM 用户 profile、nix-darwin 系统 profile 和 Nix 默认 profile 排在最前，顺序与 nix-darwin 的
  `set-environment` 相同；HM 与系统声明的 Nix 工具都优先于 Homebrew。
- 其后是 npm 全局命令目录
  `~/.local/share/npm/bin`，然后是 local/Elan/pnpm/Cargo/Go 目录、私有仓库提供的工作客户端目录和
  `.grok/bin`，再后是 Homebrew 的 `bin` / `sbin`。共享模块的 XDG pnpm 目录（`~/.local/share/pnpm`
  及其 `bin`）排在这些目录之后，astra 的 pnpm 不使用它们。
- Bash、Zsh 从 `/etc` 加载 nix-darwin 的 `set-environment`。Fish 不会加载它：Warp 启动的是 Homebrew
  Fish，nix-darwin 的 Fish 模块也未启用。因此由 HM 管理的 `~/.config/fish/conf.d/nix.fish`
  在 HM 变量之前加载同一份环境，保留终端追加的目录，并像 Fish 自身处理 path_helper 那样把
  `fish_user_paths` 放回 nix-darwin 路径之前。它导出的 guard 使非登录子 shell 和 `nix develop`
  不再重置 PATH；同名文件也取代 Nix 安装器为 Homebrew Fish 写入的 `nix.fish`。
- 嵌套的登录 shell（例如终端复用器的窗格）继承 PATH，但 Fish 的 path_helper 步骤会把 macOS 系统目录移到最前；`nix.fish`
  随后把 `home.sessionPath`
  移回它们之前。Zsh 的嵌套登录 shell 不运行 path_helper。Bash 的嵌套登录 shell 由 macOS 的
  `/etc/profile` 运行 path_helper，nix-darwin 不管理该文件，因此其中 `/usr/bin` 等系统目录会排在 Nix
  profile 之前。
- nix-darwin 的 set-environment 会重写 PATH，其 `/etc/zprofile`
  也不运行 path_helper。`modules/darwin/system-paths.nix` 在 Nix 路径之后追加 `/etc/paths` 和
  `/etc/paths.d` 中缺少的目录（例如
  `/System/Cryptexes/App/usr/bin`），Zsh、Bash 与 Fish 的结果一致。
- Homebrew 的 prefix/cellar/repository 由 HM 声明，镜像变量与激活时的 `brew bundle`
  共用一处定义；启动 shell 时无需运行 `brew shellenv`。
- Zsh 只在 HM 的 `.zshrc` 中运行一次 `compinit`；`/etc/zshrc` 的全局 `compinit`
  已关闭。存在的 Grok 和 Homebrew completion 目录在此之前追加到 `fpath`
  末尾，使 Nix 包的补全优先，与 PATH 顺序一致。

工作相关的服务地址、代理例外和客户端目录不写入本仓库。它们保存在私有 secrets 仓库（flake 输入
`mysecrets`）的 `hosts/astra/environment.nix`，由主机 HM 文件导入为 `home.sessionVariables` 和
`home.sessionPath`，值以明文进入 Nix store。Homebrew 镜像设置是公开信息，声明在
`hosts/darwin-astra/homebrew.nix`，HM 导出同一组变量。认证令牌和密钥仍由本机应用管理。

Node.js 和其它声明的软件由 HM 包集合提供。Atuin 负责历史搜索，fzf 保留命令本体并关闭重复的 shell 历史绑定。Nushell 的 argx 使用命名空间导入，保留内置
`parse`，避免干扰 fzf 初始化。Nixvim 会在插件初始化前创建标准数据目录，使 Neo-tree 在新家目录中也能正常启动。

Darwin 的 Node 24 由 `pkgs/nodejs/nodejs-slim_24.nix`
应用上游 V8 哈希修复，修正工作线程的文件描述符跟踪。未修复时 Wrangler 的构建会因 `EBADF`
失败，上游缓存中也没有 Wrangler，因此该修复对所有 Darwin 主机生效。Astra 的 Nixvim 包集合也复用这一 Node 核心。自带 Node 的包不在此列，例如 llm-agents 的 kimi-code 和使用 Node
22 的 mongosh。更新 Node 或 nixpkgs 时，需确认上游是否已包含该修复（截至 Node
24.21.0 尚未包含），再调整本地补丁。包构建保留上游检查，并额外执行文件描述符回归测试；两个测试补丁中，文件监视补丁从 Node
24.19.0 起自动不再应用。

全局 Node CLI 的安装位置都与 Node 版本无关，命令目录都在 PATH 中：

- npm（`npm i -g`）：前缀为 XDG 数据目录 `~/.local/share/npm`，命令进入
  `~/.local/share/npm/bin`，排在 `~/.local/bin`
  之前。npm 的默认前缀是 Node 自身的安装目录，对 HM 的 Node 来说是只读的 store；`~/.npm`
  是 npm 的缓存目录，共享模块的默认前缀与之重叠，所以 astra 不用这两处。Claude Code 的
  `claude update` 也装到这里，并用这里的命令检查更新结果。
- pnpm（`pnpm add -g`）：沿用 macOS 上的 `~/Library/pnpm` 布局，`globalDir`、`globalBinDir` 和
  `storeDir` 都在其中，由 `modules.pnpm` 写入
  `~/.config/pnpm/config.yaml`。已安装的全局包记录了这个 store，pnpm 不会从另一个 store 更新它们；设置了
  `XDG_DATA_HOME` 时 pnpm 的默认目录会变成 `~/.local/share/pnpm`，因此要显式指定。

pnpm 生成的命令优先使用同目录的 `node`：`pnpm env use --global <版本>`
让这些命令使用官方 Node 构建，交互 shell 中的 `node`
仍来自 HM。依赖 Node 二进制内部结构的工具需要这样做，例如 dsh 的 `node-addon-require-builtin`
在 Nix 构建的 Node 上无法定位内部模块：`--dump-config-schema`
会失败，profile 的包解析也依赖这一模块。部分包引用了未声明的依赖，例如 dsh 依赖的
`node-addon-native-custom-loader` 和 `@modelcontextprotocol/server-memory` 引用的
`zod`，pnpm 的共享全局虚拟 store 解析不到它们；`~/Library/pnpm/global/v11/pnpm-workspace.yaml` 中的
`enableGlobalVirtualStore: false` 让每个全局包像本地项目一样使用自己的 `.pnpm`
并提升依赖。该文件不由 HM 管理（pnpm 也在其中记录 `allowBuilds`
的构建批准），新机器上需在安装全局包之前手动创建它并写入这一设置。共享配置把 `fetchTimeout`
设为 300000（5 分钟）；网络较慢时这仍可能不足以下载 dsh 的 LibreOffice 套件，可在安装时加
`--fetch-timeout=600000`。

新增环境配置沿用上述 HM 声明：公开设置写入主机 HM 文件，工作相关的地址写入私有仓库的环境文件。不要把 token 或整份当前进程环境以明文复制进任何仓库；凭据需要时用 agenix 加密。

### Homebrew

Nix 声明 astra 需要哪些 Homebrew 包，Homebrew 负责安装和更新它们。清单写在
`hosts/darwin-astra/homebrew.nix`，nix-darwin 的 `homebrew` 模块据此生成 Brewfile，并在激活时运行
`brew bundle`。这样软件清单随仓库审查，重装或换机时可以还原；下列软件仍按 Homebrew 的方式安装和更新。

每个工具只保留一个来源，按以下规则选择：

- **cask**：会自行更新、需要厂商安装器或系统扩展的 GUI 应用。
  - 除 Godot 外，这些应用都会自行更新（cask 标记为
    `auto_updates`）。HM 复制的应用在每次激活时同步回 Nix 的版本，与应用内更新互相覆盖；固定的 nixpkgs 版本通常也落后于厂商发布。
  - Godot 是例外：cask 安装官方发布的正式版，不会自行更新；仓库的
    `pkgs.godot`（`pkgs/godot`）则从 Godot 开发分支的源码构建。
  - Karabiner-Elements 的虚拟键盘是 DriverKit 系统扩展，需由厂商安装器放入
    `/Applications`。固定版本的 nix-darwin `services.karabiner-elements` 所启动的
    `karabiner_grabber`、`karabiner_observer` 在当前 Karabiner-Elements 中已不存在。键位仍由
    [Karabiner 模块](../home/darwin/karabiner/README.md) 配置。
  - 仓库的 `pkgs/warp-terminal` 只构建 Linux 版本，Darwin 上没有可用的包。
  - Zotero 的数据库随版本单向升级，两个来源的 Zotero 共用 `~/Zotero`
    时，旧版本无法打开新版本升级过的数据库。因此 HM 不安装 Zotero 和 Obsidian。
- **Nix**：命令行工具、字体，以及需要固定版本或本地补丁的应用，例如 Emacs、kitty、Zed。版本由
  `flake.lock` 固定，各主机一致，可随 generation 回滚；PATH 中 Nix 排在 Homebrew 之前。字体由
  `fonts.packages` 提供，不使用字体 cask，例如 `ibm-plex` 已包含 Mono、Sans、Sans SC 和 Serif。
- **`brews`**：只列 Nix 在 astra 上不提供的命令行工具、库和服务，例如本地构建从
  `/opt/homebrew/opt/libomp` 链接的 `libomp`，以及由 `brew services` 运行、数据在
  `/opt/homebrew/var/postgresql@17` 的
  `postgresql@17`。同一命令两边都安装时，交互 shell 使用 Nix 的版本，而 launchd、GUI 应用和直接引用
  `/opt/homebrew/bin/…`
  的脚本使用 Homebrew 的版本，二者的版本和更新节奏不同，所以不保留重复。`evalTests` 检查 `brews`
  与 Nix 包不重叠。
- 唯一的重复是 Fish：Warp 的会话 shell（`~/.warp/settings.toml` 的
  `session.new_session_shell_override`）是 Homebrew 的 `/opt/homebrew/bin/fish`，PATH 中的 `fish`
  仍来自 Nix。这里不用带版本号的 Cellar 路径，它会在 `brew upgrade fish` 后失效。

激活设置：

| 设置                                              | 值        | 原因                                                                                                                                                                                                                                                                                                           |
| ------------------------------------------------- | --------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `onActivation.cleanup`                            | `"check"` | 激活开始时检查：存在清单外的包时，激活在修改系统之前失败并列出它们，不卸载任何包，所以每个 Homebrew 包都在清单中声明。`"uninstall"` 和 `"zap"` 会卸载清单外的全部包，`"zap"` 还会删除 cask 的数据，例如 `~/Library/Application Support/Zotero`、`~/.warp` 和 `~/.config/karabiner`，清单遗漏一项就会丢失数据。 |
| `onActivation.autoUpdate`、`onActivation.upgrade` | `false`   | 激活结果可重复，switch 不改变已安装的版本。除 Godot 外的 cask 由应用自行更新；Godot 和 formula 用 `brew upgrade` 显式升级。                                                                                                                                                                                    |
| `onActivation.extraEnv`                           | USTC 镜像 | 激活通过 `sudo --user` 运行 `brew bundle`，sudo 会重置环境，用户 shell 中的变量不会传入。HM 从同一处导出这些变量，交互使用与激活使用相同的镜像。                                                                                                                                                               |
| `global.brewfile`                                 | `true`    | 设置 `HOMEBREW_BUNDLE_FILE`，`brew bundle check` 和 `brew bundle cleanup` 直接使用生成的 Brewfile。                                                                                                                                                                                                            |
| shell 集成                                        | 关闭      | 不运行 `brew shellenv`，避免 Homebrew 排到 Nix 之前；Homebrew 的路径和变量由 HM 按上文顺序声明。                                                                                                                                                                                                               |

nix-darwin 激活时，Homebrew 一步位于字体和 NVRAM 之后、HM 之前。激活脚本遇到错误即停止：`brew bundle`
失败时 HM 不会激活，`/run/current-system` 也不会更新。设置 `HOMEBREW_NO_AUTO_UPDATE`
且本地已有 API 缓存时，Homebrew 不下载软件包数据；清单中的包都已安装时，这一步不需要网络。新增条目需要下载，因此修改清单后先用新产物的 Brewfile 检查，再激活。开机时的
`org.nixos.activate-system` 也运行清单检查：失败时它已重建 `/run/current-system`，但不再刷新 `/etc`
的链接，这些链接保持上次激活时的状态。

不采用的做法：

- 共享的 `modules/darwin/apps.nix` 使用 `cleanup = "zap"` 和 `autoUpdate = true`，astra 不导入。
- nix-homebrew 会接管现有的
  `/opt/homebrew`，并从 GitHub 获取 tap；astra 继续使用自行安装的 Homebrew 和国内镜像。
- 不声明第三方 tap。确需使用时，为它设置 `trusted`：Homebrew 6 起拒绝加载未信任 tap 中的包。

维护命令：

```bash
# 激活前：新产物声明的包都已安装（与激活一样，不检查升级）
brew bundle check --no-upgrade --verbose --file="$(grep -o -m1 '/nix/store/[a-z0-9]*-Brewfile' result-astra/activate)"
# 列出新产物清单外的包，即激活检查会报告的包；不加 --force 时不删除任何内容
brew bundle cleanup --file="$(grep -o -m1 '/nix/store/[a-z0-9]*-Brewfile' result-astra/activate)"
```

不带 `--file` 时，这两条命令读取
`HOMEBREW_BUNDLE_FILE`，即启动当前 shell 时已激活系统的 Brewfile；修改清单后它与新产物不同，因此只用于激活后的验收。

- 新增软件时按上面的规则选择来源，只在 Nix 没有合适的包时加入 `brews`。用 `brew install`
  临时安装的包也会让下一次激活失败：加入清单，或用 `brew uninstall`
  卸载。`brew bundle cleanup --force` 会卸载清单外的全部包，只在确认列表后使用。
- 升级：`brew upgrade`
  升级 formula 和不会自行更新的 cask（Godot）；`just brew-upgrade`（`brew upgrade --cask --greedy`）还会升级会自行更新的 cask。
- 工具改由 Nix 提供：加入 Nix 包集合并激活后，从 `brews` 删除，再
  `brew uninstall`。卸载前确认没有 shebang、IDE 设置或登录 shell 引用 `/opt/homebrew/bin/…`。

### 包来源与构建成本

Astra 优先复用固定 nixpkgs 版本的二进制缓存。原生 Emacs 和修复后的 Node 需要本地定制构建；相同输入对应的 store 产物存在时可直接复用。`modules/darwin/overlays.nix`
让所有 Darwin 主机上仅在构建或测试时使用 Node 的包复用上游构建：Zotero（基于 Firefox
ESR 源码构建）、Marksman（基于 .NET 源码构建）、Furo 的静态资源、Arrow 安装检查用的 Azurite，以及 Argo
CD 嵌入 Go 程序的静态网页资源。没有这层复用，`fern` / `frieren` 也要从源码重建 Firefox
ESR、.NET、kitty 和数十个 Python 包。这些包的运行依赖不含 Node；nixpkgs 中运行时使用 Node 的工具仍使用修复版。

astra 启用 `modules.darwin.upstreamOpenldap`（定义在
`modules/darwin/overlays.nix`），OpenLDAP 使用同一 nixpkgs
pin 的原始配方及测试设置，使 GnuPG、Pass 等依赖保持上游缓存身份。其它主机使用
`modules/base/overlays.nix`
中关闭测试的 OpenLDAP 覆盖；缓存身份一致不保证缓存服务器一定有对应产物或当前网络能够下载。

Zed 使用 `pkgs.zed-editor-bin` 提供的官方 macOS 应用，版本跟随 Zed 的最新稳定版（不低于 nixpkgs 的
`zed-editor`，astra 的 eval 测试检查这一点），下载地址和 SHA-256 固定在仓库中。打包保留完整签名 App、`zed`
/ `zeditor`
命令入口，沿用共享 HM 设置并关闭应用自行更新。它不构建 Rust 应用和测试依赖，也不提供独立的
`remote_server` 输出；远程项目按官方应用的方式获取对应服务端。其它主机使用 nixpkgs 的
`zed-editor`。更新时两个架构的 DMG 哈希都要换，可直接用 GitHub API 返回的 asset
digest。构建时只做静态检查：`zed` / `zeditor`
链接，以及构建沙盒关闭时（Nix 在 Darwin 上的默认设置）的 App 版本和完整签名。构建中不执行 CLI，以免签名应用触发 macOS 保护、妨碍 Nix 整理输出元数据；CLI 在产物完成后手动验证（见“验证应覆盖”）。

Android 命令行工具在 Darwin 使用官方 macOS 归档：nixpkgs 在所有平台上都重新打包 Linux 归档，而 macOS 归档带有 Google 签名的 Darwin 原生代码，包括 JNI 库和 cmdline-tools
23.0 起新增的原生 `android`
CLI。本地包只替换归档来源，其中的脚本已带 Mac 标题。Google 的 Linux 和 macOS 归档使用相同的构建号；本地包固定为[仓库索引](https://dl.google.com/android/repository/repository2-3.xml)中最新的构建，并用它作为包版本，所以可能比 nixpkgs 新，eval 测试检查它不低于 nixpkgs 的版本。自 cmdline-tools
22.0 起，macOS 归档按架构分为 `mac_arm64` 和 `mac_x86_64` 两个文件（不带架构的
`commandlinetools-mac` 文件名止于 15641748），两个哈希都要更新。23.0 起 `sdkmanager` 已弃用，会转调
`android sdk`；它仍接受显式的 `--sdk_root=<SDK 目录>`，用来指定可写 SDK，不把 SDK 安装进只读 store。

`pass-import`
保留全部导入后端。上游缓存中没有 Darwin 的 Jeepney，而它的测试需要 Nix 构建中不可用的 launchd 会话总线；`modules/darwin/overlays.nix`
让 Darwin 主机构建时使用临时 Unix D-Bus 会话运行原有测试，不安装或启动常驻 D-Bus 服务。

构建计划中的 derivation 还包括配置文件、命令包装和 shell 补全，不能把条目总数当作需要从源码编译的软件数量。固定 inputs 或修改底层依赖后，相关缓存身份可能变化；不通过关闭测试来减少构建时间。

## 求值、构建与审查

新增源码必须进入 Git index，flake 才能看到它。此要求不等于需要提交或推送。保持 `flake.lock`
不变，分别验证 system 和集成 HM 的具体产物；只看 `evalTests` 不足以证明构建成功。

私有输入 `mysecrets` 通过 `git+ssh`
获取：首次获取或更新它时，当前用户需能用 SSH 访问 GitHub。root 没有这份 SSH 凭据，Nix 也只在需要时才把输入复制进 store，因此以 root 重新求值 flake 会因无法获取它而失败。切换时激活用户已构建的产物，不以 root 重新求值（见“激活与运行验收”）。

```bash
nix eval --no-write-lock-file --json .#evalTests
nix eval --no-write-lock-file --raw .#darwinConfigurations.astra.system.drvPath
nix eval --no-write-lock-file --raw .#darwinConfigurations.astra.config --apply 'c: c.home-manager.users.${c.system.primaryUser}.home.activationPackage.drvPath'
nix build --no-write-lock-file --max-jobs 1 --cores 1 --out-link result-astra .#darwinConfigurations.astra.system
```

可在输入已缓存时增加 `--offline`。`result-astra` 不覆盖其它构建的 `result`
链接。构建默认低并发；提高核数前检查可用内存和磁盘。`--max-jobs` / `--cores`
不是内存上限。构建使用当前 daemon 配置，待部署的缓存设置在激活前尚未生效。

验证应覆盖：

- `astra` 平台、主机名、系统用户、HM 用户及家目录一致。
- Emacs 为 NS/arm64；`~/.config/doom` 链接到配置仓库，Doom 激活步骤存在。
- 不生成用户 `~/.ssh` 配置、原作者公钥/签名身份、Rime/AeroSpace 文件或未配置的工作 secret/provider。
- shell 在无 secret 的隔离环境中可启动；路径、代理例外及常用命令符合配置。
- 从 Warp 的 Fish 冷启动时能找到系统 profile 中的命令（如
  `darwin-rebuild`）；其非登录子 shell 保持相同的 PATH，不被 nix-darwin 的 `set-environment`
  重置；嵌套登录 Fish 中 Nix profile 仍排在 `/usr/bin` 之前。
- Zsh 交互 shell 只运行一次 `compinit`。
- Node 工作线程的文件读写和退出无描述符错误，pnpm /
  Wrangler 实际可运行；编辑器工具的运行依赖不包含已知有问题的 Node 产物。
- pnpm 全局包使用 `~/Library/pnpm` 布局，`~/Library/pnpm/global/v11/pnpm-workspace.yaml` 含
  `enableGlobalVirtualStore: false`。
- Zed 官方 App 的架构、签名、版本和两个 CLI 入口有效；Android 工具的解包路径和启动命令有效。
- Nixvim 启用共享声明的 Nix、Rust、Go、Python 和 Shell 语言服务器，验证实际连接，不仅检查服务器包是否存在。
- `fern` / `frieren` 和既有独立 HM 输出的用户身份及相关默认行为保持；共享模块修改按范围扩展回归。
- 实际 system/HM 构建完成，并审查全部 activation 脚本与 HM `home-files`。

求值成功、构建成功和系统激活成功是不同结果。来源下载失败、既有上游问题及新增回归应分别记录。验证日志和本机配置盘点保存在仓库外，不将临时测试目录写入配置。

Nixvim 在 astra 使用与其版本匹配的 26.05 包集合；其求值库仍来自全局 26.11，因此会报告版本未完全对齐的 warning。保留该提示，构建和运行结果单独验证；不为消除提示修改所有主机共用的 input
follows。

## 首次激活准备

首次激活前，基于精确构建产物列出将改变的对象。记录文件内容、符号链接目标、权限/属主、备份目标冲突以及原本不存在的路径；备份保存在权限受限的仓库外目录。

| 对象           | 必须检查的内容                                                                                                                                    |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Nix            | 当前与目标 Nix 版本、store schema / 实验性特性、daemon plist / 加载状态、`/etc/nix`、安装器 receipt、profiles                                     |
| 系统文件       | 产物声明的全部 `/etc` 文件、`/etc/static`、系统 shell、PAM sudo / sudo_local；系统 SSH host key 及其 `.pub` 的存在性、大小和权限                  |
| 系统字体       | `/Library/Fonts/Nix Fonts` 的现有内容；该专用目录会同步并删除非声明字体                                                                           |
| launchd        | 全部新增/改变的 plist、各 domain 的加载和 disabled 状态，含开机激活服务                                                                           |
| 用户文件       | HM `home-files` 中每个实际目标、备份冲突；尤其 Zsh、Bash、终端和编辑器配置                                                                        |
| HM 直接写入    | `~/Applications/Home Manager Apps`、`~/Library/Fonts/HomeManager`、`~/.config/zed/settings.json`，须单独备份                                      |
| 用户服务与状态 | `~/Library/LaunchAgents/org.nix-community.home.tldr-update.plist`、用户 profile、HM gcroots、Bat 缓存及现有 `~/.gnupg` 的元数据                   |
| 身份与连接     | Git 有效身份/include、SSH/Colima 连通性；仅记录必要元数据，不输出私钥或凭据                                                                       |
| 主机与应用     | 三种主机名、时区、现有 Homebrew inventory 与生成的 Brewfile（`brew bundle check` / `brew bundle cleanup`）、`/Applications/Nix Apps` 及旧应用链接 |

HM 的备份扩展名为
`home-manager.backup`，不覆盖已存在的同名备份。它只保护 HM 正常链接流程，不覆盖 activation 脚本直接写入的对象。HM 在应用和字体目录使用
`rsync --delete`，会删除目录中不属于生成结果的内容。Zed 设置会原地合并并重写，声明配置覆盖重叠键，注释和格式不保留；解析失败时按空对象合并。因此不能仅根据
`home-files` 清单或备份扩展名判断用户文件是否受到保护。当前 `.zprofile` / `.zshrc`
的有效设置需与生成的新文件核对，不能只备份后忽略其行为。

目标 Nix 版本低于现有安装版本时，需核对 store、daemon 协议和已使用的实验性格式。例如 Nix
2.35 改变了实验性内容寻址构建（CA）的记录、缓存和协议格式；相同的普通 store
schema 不能证明所有实验性用法均兼容。另行确认现有安装器和 daemon 能由 nix-darwin 接管，版本兼容不替代首次激活检查。

即使没有自定义桌面 defaults，nix-darwin 仍会管理 `/etc`、Nix daemon、系统 shell，系统级 SSH 配置以及
`/Applications/Nix Apps` 的应用同步；其中应用同步使用 `rsync --delete`。系统字体同步也会清理
`/Library/Fonts/Nix Fonts`。系统 RSA、ECDSA、Ed25519 host key 不存在或为空时，会条件生成密钥及配对
`.pub`；非空现有私钥不被这一片段替换。只在已审查的专用目录中执行这些同步，不扩大到整个 Applications 或 Fonts 目录。nix-darwin 同时设置
`HostName`、`ComputerName` 和 `LocalHostName`；新机器上若只设置过后两者，首次激活会新增 `HostName`。

HM 会安装并加载每周更新 tldr 缓存的用户 LaunchAgent，重建 Bat 缓存，必要时创建 `~/.gnupg`，维护
`~/.local/state/home-manager/gcroots`；集成模式还会移除用户 profile 中已有的独立 `home-manager-path`
条目。Kitty、Helix 配置变化时会通知运行中的程序重载。应用复制的权限探测会 touch
`~/Applications/Home Manager Apps` 中各 App 的
`.DS_Store`；探测失败且处于 Aqua 会话时，会执行对所有应用生效的
`tccutil reset SystemPolicyAppBundles`
并重新请求授权。给执行激活的终端授予「App 管理」权限可避免这次重置；首次激活时该目录还不存在，不会探测。

astra 不管理 `/etc/pam.d/sudo_local`，激活的 PAM 步骤只读取 `/etc/pam.d/sudo`，不在 `/etc/pam.d`
下写入。macOS 隐私保护（TCC）会拒绝没有完全磁盘访问权限的进程在该目录创建文件；由 nix-darwin 管理
`sudo_local` 时，激活会在创建它的链接时中止。

「system defaults」步骤以 root 写入 `/Library/Preferences/SystemConfiguration`
中的 NetBIOS 名称。在已登录的图形会话中从终端执行激活，出现管理权限提示时允许；预先给终端授予「完全磁盘访问权限」最稳妥。激活中途因权限失败时，授权后重新执行即可。

Nix 安装器的开机 `repair`
hook（`systems.determinate.nix-installer.nix-hook`）可以保留：2.35.2 版本跳过已是符号链接的 shell
profile 和 `/etc/zshenv`，不会改回 nix-darwin 管理的文件。激活会重启 Nix
daemon，期间不要运行其它 Nix 构建。

先审查并构建具体修改，再确认系统激活。不要将 activation 的 dry-run 或 checks 视作无副作用的只读检查。

## 激活与运行验收

以下命令会修改系统，仅在产物、文件影响和备份均已审查后执行。它们激活已审查的
`result-astra`，即该 pin 的 `darwin-rebuild switch` 在构建之后执行的两步：先把 system
profile 指向产物，再运行该产物的 activation。执行前确认 `result-astra`
仍指向审查过的产物，并用“Homebrew”一节的两条命令确认清单检查会通过、Homebrew 一步无需安装或下载。

```bash
sudo -H env NIX_REMOTE=daemon ./result-astra/sw/bin/nix-env -p /nix/var/nix/profiles/system --set "$(readlink -f result-astra)"
sudo -H ./result-astra/sw/bin/darwin-rebuild activate
```

与该 pin 的 `darwin-rebuild`
一样，root 使用自己的 HOME（`-H`），并通过 daemon 访问 store（`NIX_REMOTE=daemon`），而不是直接以产物中的 Nix 版本打开 store。

不要改用 `sudo darwin-rebuild switch --flake .#astra`：它以 root 重新求值 flake，root 无法获取私有
`mysecrets`，而且可能选中与审查时不同的产物。只执行 `activate` 而不更新 system
profile，与 switch 并不等价。升级 nix-darwin 后需重新核对 switch 在构建之后的步骤。

首次激活前 `just`、`nu` 和 `darwin-rebuild`
都不在 PATH 中，它们随这次激活进入 profile：可直接运行上面两条命令，或在
`nix shell nixpkgs#just nixpkgs#nushell` 提供的 shell 中运行 `just local`。`just local` 和
`just local debug` 先以当前用户构建 `result-<host>`（默认
`--max-jobs 1 --cores 1`，`just local normal <jobs> <cores>`
可在 1 到 16 之间调整），再按上述两步激活同一产物。macOS recipe 按 `scutil --get HostName`
选择 host，未设置 `HostName` 时改用
`LocalHostName`：局域网中有设备使用同一名称时，Bonjour 会把 LocalHostName 改成 `astra-2`
之类。构建链接为 `result-<host>`，不会覆盖独立包的 `result`。

完成后检查 system profile、`/run/current-system` 和 generation 对应同一产物，HM 激活成功，Nix
daemon、sudo/PAM、新 login/interactive shell、Git/SSH/Colima 及 Emacs
GUI 实际可用。核对 HM 应用、字体、Zed 设置和 tldr
LaunchAgent 的实际状态，`brew bundle check --no-upgrade` 通过，`brew bundle cleanup`
不列出任何包。集成 HM 不要求独立 `home-manager generations` 列表出现新项。

## 失败恢复

首次接管没有旧 nix-darwin
generation。激活失败可能留下新 profile 与部分已写入的文件；不要反复 switch、删除 profiles、执行 GC 或卸载 Nix。保留可用终端和失败日志，核实实际文件与 launchd 状态后按备份恢复。

Homebrew 清单检查失败时，激活在修改系统之前停止，不卸载任何包；此时第一条命令已把 system
profile 指向新产物，`/run/current-system` 仍是上次激活的产物。卸载列出的包后重新运行同一产物的
`activate`，或把它们加入清单后重新构建并激活。Homebrew 一步失败时，此前的系统步骤已经完成，HM 尚未激活，`/run/current-system`
也未更新。按输出修正清单或网络问题后，重新运行同一产物的
`activate`；这一步只安装缺少的包，不会卸载任何包。

恢复前确认新增或变更的开机激活服务是否会重放失败配置；按准确 label/domain 处理，不能盲停原有 Nix
daemon。之后恢复文件、权限、链接和原先不存在项，再恢复所需服务状态。后续已有成功 generation 时可回退，但回退仍执行 activation，不会原子还原所有用户文件和应用状态。
`just darwin-rollback` 通过 `sudo` 调用 `/run/current-system`
中的回退程序，要求已激活的 nix-darwin 系统及可回退的旧 generation；它不是首次接管失败时的恢复方法。

`darwin-uninstaller` 与安装器的 `/nix/nix-installer uninstall`
不同：后者会卸载 Nix 并删除其 store 卷，不属于首次激活的普通恢复办法。卸载或删除数据需另行确认。

## 固定版本参考

- [nix-darwin Nix 托管](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/nix/default.nix)
- [nix-darwin 应用同步](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/system/applications.nix)
- [nix-darwin PAM](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/security/pam.nix)
- [nix-darwin Homebrew](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/homebrew.nix)
- [nix-darwin 激活顺序](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/system/activation-scripts.nix)
- [nix-darwin Karabiner-Elements](https://github.com/nix-darwin/nix-darwin/blob/d5bd9cd77aea4c0a8f49e7fd85545671a208ed15/modules/services/karabiner-elements/default.nix)
- [Home Manager activation](https://github.com/nix-community/home-manager/blob/f938277527aa084929261879d50d9832b9eab6d3/modules/home-environment.nix)
- [Home Manager Darwin 集成](https://github.com/nix-community/home-manager/blob/f938277527aa084929261879d50d9832b9eab6d3/nix-darwin/default.nix)
- [Home Manager 应用复制](https://github.com/nix-community/home-manager/blob/f938277527aa084929261879d50d9832b9eab6d3/modules/targets/darwin/copyapps.nix)
- [Home Manager 字体同步](https://github.com/nix-community/home-manager/blob/f938277527aa084929261879d50d9832b9eab6d3/modules/targets/darwin/fonts.nix)
- [Home Manager Zed 设置](https://github.com/nix-community/home-manager/blob/f938277527aa084929261879d50d9832b9eab6d3/modules/programs/zed-editor.nix)
- [Zed 官方发布](https://github.com/zed-industries/zed/releases)
- [Nix 2.35 实验性 CA 格式变化](https://github.com/NixOS/nix/blob/2.35.2/doc/manual/source/release-notes/rl-2.35.md)
