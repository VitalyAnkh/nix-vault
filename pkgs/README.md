# self-host pkgs

## 如何定义新的包

支持两种格式: - /pkgs/package-name/package.nix 最终会得到 pkgs.package-name - /pkgs/<folder>/{a.nix,
b.nix} 最终会得到 pkgs.a pkgs.b

定义完后，git add file 即可。

与 nixpkgs 已有属性同名的文件会替换该属性，例如 `jetbrains-toolbox/package.nix` 替换
`pkgs.jetbrains-toolbox`。callPackage 的参数集把 nixpkgs 包集合合并在本仓库的包之后，同名时以 nixpkgs 为准：本目录的文件把这类属性声明为参数时，得到的都是 nixpkgs 中的原包，因此可以在其上
`overrideAttrs`。`modules/base/overlays.nix`、`lib/homeManagerConfiguration.nix` 和
`outputs/default.nix` 三处调用都要保持这个合并顺序，否则替换同名属性的文件会无限递归。

## Unreal 说明

`pkgs/unreal` 是一个本地 Unreal Engine 5 wrapper：

- 必须通过 `UE_SRC` 环境变量指定你的 Unreal 源码仓库
- 如果没设置 `UE_SRC`，wrapper 会直接报错退出，不会启动 Unreal
- 只包装你本地的源码树，不会把整个 Unreal 仓库复制进 `/nix/store`
- 可直接用 `nix build .#unreal` 或 `nix run .#unreal`

## 如何通过 nvfetcher 修改软件

例如，emacs，在 `nvfetcher.toml` 中定义

```toml
[source-emacs-master-igc]
# Prefer GitHub HTTP API for version checks (src.git / git ls-remote often times out).
# Regex anchors to the top-level commit sha only (JSON also has tree/parent shas;
# nvchecker would otherwise pick the lexicographic max of all matches).
src.webpage = "https://api.github.com/repos/emacs-mirror/emacs/commits/feature/igc3"
src.regex = "\\A\\s*\\{\\s*\"sha\"\\s*:\\s*\"([0-9a-f]{40})\""
fetch.github = "emacs-mirror/emacs"
```

然后在 `emacs/emacs-master-pgtk-with-igc.nix` 中，传入的函数加上 `source-emacs-master-igc`
参数，并替换掉原有的src

```nix
{ source-emacs-master-igc, emacs, ... }:
emacs.overrideAttrs (
  old: {
    ...
    inherit (source-emacs-master-igc) src; # 替换 src
    ...
  }
)
```

## 如何更新软件的源码?

在当前目录下执行：

```bash
cd pkgs
nvfetcher --keep-old --keep-going
```

nvfetcher 写出的 `_sources/generated.json` 和 `_sources/generated.nix` 未经格式化。提交前在 `pkgs`
目录中格式化，使 diff 只包含版本变化：

```bash
prettier --write _sources/generated.json
nixfmt _sources/generated.nix
```

更新 `source-emacs-master-igc` 后，`emacs/emacs-master-pgtk-with-igc.nix` 的 `version` 必须与新源码
`configure.ac` 中 `AC_INIT` 的版本一致，否则 `postPatch`
会让构建失败。本地补丁和 nixpkgs 的 Emacs 补丁都要能打在新源码上：IGC 源码已经包含 nixpkgs 以
`CVE-2024-53920.patch` 回移的修复，所以该补丁被过滤掉。`emacs-lsp-booster` 的 `version`
同样要与源码的 `Cargo.toml` 一致，可以查看 `_sources` 中复制的
`Cargo.lock`。新的 Emacs 激活后，在新登录 shell 中重新运行
`doom sync`，否则 Doom 仍加载旧构建的 Lisp，原生编译全部失败（见
[astra 文档](../docs/astra-macos-host.md)的 Emacs 一节）。

然后 `git add` / `git commit` 更新的 `_sources/generated.nix`、`_sources/generated.json`，以及
`cargo_lock` 产生的 `Cargo.lock` 等附属文件。

推荐参数：

- `--keep-old`：不要在运行开始时删掉旧的 `Cargo.lock` 等附属文件（中断时树仍可用）
- `--keep-going`：单个源失败时尽量继续其它源
- `-f '^source-godot-master$'`：只更新匹配的包

### 常见问题

**`Shake failed to acquire a file lock ... .shake.lock`**

有另一个 `nvfetcher` 实例仍在运行，或上次被 `Ctrl-Z` / 强杀后锁未释放：

```bash
# 查看是否还有 nvfetcher
ps -C nvfetcher -o pid,stat,etime,cmd
# 若进程已死或处于 T(stopped)，清掉锁
rm -f ~/.local/share/nvfetcher/.shake.lock
# 若进程卡死，先 kill 再清锁
kill <pid>   # 必要时 kill -9
rm -f ~/.local/share/nvfetcher/.shake.lock
```

**`Failed to run nvchecker: GetVersionError('command timed out')`**

`src.git` 会走 `git ls-remote`，在代理/弱网下对大仓库容易超时。本仓库的 GitHub源统一用
`src.webpage` + GitHub Commits API 做版本检查，并用 `fetch.github` 走 HTTP tarball（比 `fetch.git`
全量 clone 更稳）。

**`nix-prefetch-url` 404 on a GitHub archive**

若 `src.regex` 写得太宽，会匹配到 Commits API JSON 里的 tree/parent
`sha`。nvchecker 会对所有匹配取“最大版本”，从而拿到错误 commit。请用 `\\A\\s*\\{\\s*\"sha\"...`
锚定顶层 commit。

**跑到一半中断后 `_sources/` 里 `Cargo.lock` 目录消失**

默认 nvfetcher 启动会删旧附属文件。请始终加 `--keep-old`，并用 `git restore pkgs/_sources/`
恢复误删文件。

## 手动固定的包

下列包不经过 nvfetcher，版本和哈希直接写在包文件中，更新时手动改到最新版：

| 文件                               | 最新版本的来源                                                                                                      | 要更新的内容                                                                                                                                         |
| ---------------------------------- | ------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------- |
| `zed-editor/zed-editor-bin.nix`    | [Zed 最新稳定版](https://github.com/zed-industries/zed/releases/latest)                                             | `version`，aarch64 和 x86_64 两个 DMG 的哈希                                                                                                         |
| `android-studio-tools/package.nix` | [仓库索引](https://dl.google.com/android/repository/repository2-3.xml)中最新的 cmdline-tools 构建号                 | `version`，`mac_arm64` 和 `mac_x86_64` 两个归档的哈希                                                                                                |
| `computer-use-linux/default.nix`   | [最新 release](https://github.com/agent-sh/computer-use-linux/releases/latest)                                      | `version`，x86_64 和 aarch64 两个文件的哈希                                                                                                          |
| `cua-driver/default.nix`           | [trycua/cua](https://github.com/trycua/cua/releases) 中最新的 `cua-driver-rs-v*`                                    | `version` 与哈希                                                                                                                                     |
| `jetbrains-toolbox/package.nix`    | [JetBrains 的最新 release](https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release) | Darwin 的 `version` 与 `macM1` DMG 的哈希（`checksumLink` 给出 SHA-256）；Linux 沿用 nixpkgs 的版本和哈希，只把下载地址换成 `download.jetbrains.com` |
| `godot/package.nix`                | [OpenXR-SDK-Source](https://github.com/KhronosGroup/OpenXR-SDK-Source) 的 `main`                                    | OpenXR loader 的 `rev`、`hash` 和 `version` 中的日期；Godot 本身由 nvfetcher 更新                                                                    |

`codex-desktop` 的后端版本直接读取源码中的 `Cargo.toml`，不需要手动维护。

获取哈希：

- `fetchurl` 下载的文件（Zed、computer-use-linux、cua-driver）：GitHub
  API 给出每个 release 资产的 SHA-256，不必先下载：

  ```bash
  curl -s https://api.github.com/repos/zed-industries/zed/releases/latest |
    jq -r '.assets[] | select(.name | endswith(".dmg")) | "\(.name) \(.digest)"'
  # digest 形如 sha256:<十六进制>，换成 SRI 格式
  nix hash convert --hash-algo sha256 --to sri <十六进制>
  ```

- `fetchzip` 解包后的哈希（Android）：`nix store prefetch-file --unpack --json <url>` 输出中的
  `hash`。
- `fetchFromGitHub`（OpenXR）：`nix flake prefetch --json github:<owner>/<repo>/<rev>` 输出中的
  `hash`。

GitHub 对单个连接的 release 下载可能很慢。可以多连接分段下载，再把文件加入 store，`fetchurl`
会直接使用它（文件名必须与 `fetchurl` 的 `name` 相同，默认是 URL 的最后一段）：

```bash
nix shell nixpkgs#aria2 -c aria2c -x 16 -s 16 -d /tmp/zed <资产 URL>
nix-store --add-fixed sha256 /tmp/zed/Zed-aarch64.dmg
```
