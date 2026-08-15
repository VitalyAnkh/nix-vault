# self-host pkgs

## 如何定义新的包

支持两种格式: - /pkgs/package-name/package.nix 最终会得到 pkgs.package-name - /pkgs/<folder>/{a.nix,
b.nix} 最终会得到 pkgs.a pkgs.b

定义完后，git add file 即可。

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

然后在 `emacs/emacs-master-igc-pgtk.nix` 中，传入的函数加上 `source-emacs-master-igc`
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
