# 吸收上游改进

本仓库 fork 自 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)。`vr`
是唯一的长期分支，eva（NixOS）和 astra（macOS）都从它构建。本文是吸收上游改进的固定流程，Darwin 的审查进度记录在
[`upstream-sync.toml`](./upstream-sync.toml)。

上游远程名为 `ryan`：

```bash
git remote add ryan git@github.com:ryan4yin/nix-config.git
git remote set-url --push ryan no_push # 防止误推
git fetch ryan main
```

## 分工

- **eva 合并 `ryan/main`。** Linux 与共享文件按 [AGENTS.md](../AGENTS.md) 的
  `<project_merge_protocol>` 处理，验证后推送 `vr`。
- **astra 按路径移植 Darwin 改动，不合并 `ryan/main`。**
  Git 按提交合并：eva 合并之后，这些提交中的 Darwin 改动在 Git 看来都已合入，即使解决冲突时保留了本地版本，以后的合并也不会再带来它们。所以 astra 拉取 eva 的合并后要逐条审查，需要的手工移植，再更新
  `upstream-sync.toml` 的 `darwin.reviewed`。
- **共享文件的取舍在 eva 上决定。** `home/base`、`modules/base`、`pkgs`、`flake.lock`
  等由 eva 的合并决定；astra 只验证它们不破坏 astra，只影响 Darwin 的问题在 astra 上修。astra 审查时发现、但需要修改共享文件的上游改动记入下文“待处理”，留给 eva。

## 日常纪律

- 每台机器开始工作前 `git pull --ff-only`，完成一组提交就推送。
- 不在长期分支上积压改动。2026-10 合入的 astra 分支基于九月同步之前的
  `vr`，合并时多个文件整个取了一侧：Emacs
  pin、justfile 配方、README 与 secrets 文档的改动丢失，上游已删除的 AeroSpace 模块也被带回，事后才逐个补回。长期分支合入
  `vr` 之前，先把最新的 `vr` 合入该分支并验证。
- 每次合并后运行合并审计（见下节）。
- 上游没有 `pkgs/`，`pkgs/_sources/generated.{json,nix}`
  只会在本地分支之间冲突。这时按源逐条取较新的 pin，或者合并后重新运行 nvfetcher（见
  [pkgs/README.md](../pkgs/README.md)），不要整个文件取一侧。
- macOS 的文件系统不区分大小写，不要检出同时跟踪 `Justfile` 和 `justfile`
  的旧提交。只需快进本地分支时用 `git fetch . <分支>:vr`，不切换工作区。

## 合并审计

```bash
just merge-audit <合并提交>                    # 列出需要复查的文件
just merge-audit --diff <合并提交> -- <路径>...  # 显示干净三方合并与合并结果的差异
```

它把合并结果与两个父提交的干净三方合并（`git merge-file`）逐文件比较，列出结果不同的文件、modify/delete 冲突的结果，以及只有一侧修改、结果却不是那一侧的文件。`result is ours`
或 `result is theirs`
表示整个文件取了一侧，另一侧的改动全部丢失，即使它们本可以无冲突地合并。`--diff` 中的 `-`
行是干净合并中有、合并结果中没有的内容。列出的文件不一定有问题，例如两侧对同一处用了不同的措辞，但每个都要看过。

## eva：合并 ryan/main

1. `git fetch ryan main`，先读提交说明：`git log --format='%h %ad %s%n%b' $(git merge-base vr ryan/main)..ryan/main`。
2. `git merge ryan/main`，按 `<project_merge_protocol>` 解决冲突：
   - `flake.lock`
     按 input 逐条选择：与本地定制兼容时取较新的，否则保留本地的并记下原因；不要整个文件取一侧。
   - 上游的 `Justfile` 对应本地的 `justfile`，用
     `git merge-file justfile <merge base 的 Justfile> <ryan 的 Justfile>` 三方合并，不留下
     `Justfile`。
   - 文档和其它配置同样逐处合并，不要因为一侧有本地定制就整个文件取这一侧。
3. `just merge-audit HEAD`，复查列出的每个文件。
4. nixpkgs 更新后，检查 `pkgs/` 中覆盖 nixpkgs 的包和手动固定的包（见
   [pkgs/README.md](../pkgs/README.md#手动固定的包)）。
5. 验证：`just test`（`evalTests` 也包含 Darwin 主机的测试）和
   `nixos-rebuild build --impure --max-jobs 1 --cores 1 --flake .#eva`。
6. 推送 `vr`。

## astra：审查 Darwin 改动

1. `git pull --ff-only` 拿到 eva 的合并，然后 `git fetch ryan main`。
2. `just upstream-darwin` 列出 `darwin.reviewed` 之后、已合入 `HEAD` 的上游提交中修改了
   `darwin.paths` 的部分；加参数 `ryan/main` 还会列出尚未合并的提交。逐条用 `git show <提交>`
   阅读改动和提交说明。
3. 对 `darwin.paths` 中的路径运行
   `git diff $(git merge-base HEAD ryan/main) HEAD -- <路径>`，把每处差异归为三类：
   - (a) 上游的改动没有被采纳：移植；
   - (b) 本地有意的定制：保留；
   - (c) 上游的改进但与本地约定冲突：不移植，在代码注释或下文“有意保留的差异”中写明原因。

   只看提交列表不够。merge
   base 过旧或分支基于同步之前时，文件可能整个停留在旧版本：上游改写过历史，2026-04 的 61aed7c6 合并的 merge
   base 是 2023 年的提交，合并时原样保留了 vr 一侧的
   `modules/darwin/apps.nix`，上游 2025-11 到 2026-04 间对它的修改都没有进来，之后的合并也不会再带来这些修改。

4. 检查被上游删除后又出现的文件：`git diff --name-only --diff-filter=D <合并前的 vr> <合入的上游提交>`
   列出的路径不应再出现在 `HEAD` 中。
5. 上游删除模块或选项时，先用 `git grep 'modules\.<名字>\.'`
   找出主机中的设置。用户自己的设置注释掉而不是删除，同时更新 eval 测试。
6. Homebrew 条目用 formulae.brew.sh 的 API（`https://formulae.brew.sh/api/formula/<名字>.json`、`.../api/cask/<名字>.json`）和 homebrew-cask 的提交历史核对是否已删除、改名或停用。Homebrew
   6 默认要求信任 tap，nix-darwin 对全限定名（`<用户>/<tap>/<名字>`）的条目默认信任。fern/frieren 使用
   `cleanup = "zap"`：清单中删除或注释掉的条目在下次激活时被卸载并清除数据。astra 使用
   `cleanup = "check"`：有未声明的包时激活中止。
7. 验证：`just test`；astra、fern、frieren 的
   `system.drvPath`；最后在后台构建 astra：`nix build --no-write-lock-file --max-jobs 1 --cores 1 --out-link result-astra .#darwinConfigurations.astra.system`。新增或删除的文件要先进入 git
   index。
8. 提交移植，把 `darwin.reviewed` 改为本次审查到的上游提交，并在提交说明中写明。激活另行决定。

## 当前状态

`darwin.reviewed` 为 9ab5eca6，即目前合入 `vr`
的最新上游提交。2026-10-12 按上述流程审查了此前所有的上游 Darwin 改动并完成移植。

### 有意保留的差异

相对上游 9ab5eca6，`darwin.paths` 中只剩下面这些差异：

| 路径                                                                             | 类别 | 原因                                                                                                                         |
| -------------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------- |
| `home/darwin/shell.nix`                                                          | c    | 上游 6218bb22 把 Homebrew 放到 PATH 最前；本地追加在后，使 Nix 包优先于 Homebrew，astra 的 PATH 顺序依赖这一点               |
| `home/darwin/ssh.nix`                                                            | c    | 上游 b44d2770 改用系统级 SSH 配置并删除此文件；独立 HM 输出 `vitalyr@aarch64-darwin` 不经过 nix-darwin，主机别名只能来自这里 |
| `home/darwin/default.nix`                                                        | b    | Home Manager 26.05 在 Darwin 上默认 `programs.man.package = null`，因此关闭 man 缓存                                         |
| `home/darwin/proxy`、`home/darwin/rime-squirrel.nix`                             | b    | 加了启用开关；proxychains 的链接指向 `repoRoot` 下的仓库，而不是上游的 `~/nix-config`                                        |
| `home/darwin/karabiner`、`home/darwin/input-source-pro`、`home/darwin/README.md` | b    | astra 的键位与输入法                                                                                                         |
| `modules/darwin/{overlays,nix-daemon,system-paths}.nix`                          | b    | 所有 Darwin 主机共用的本地模块                                                                                               |
| `modules/darwin/system.nix`、`modules/darwin/README.md`                          | b    | 注释拼写与文案                                                                                                               |
| `secrets/darwin.nix`                                                             | b    | GPG 子密钥的文件名                                                                                                           |
| `home/hosts/darwin`、`hosts/darwin-astra`、`outputs/aarch64-darwin`              | b    | astra 主机、fern 的 Emacs、独立 HM 输出与 eval 测试                                                                          |

### 待处理

- 留给 eva 的共享文件改动：
  - 上游 260da1ee 把工作 alias 的 secret 改名为 `nushell-secrets.nu`。`secrets/darwin.nix`
    已采纳，`home/base/tui/shell/default.nix` 和 `secrets/nixos.nix` 仍使用
    `alias-for-work.nushell`，所以 fern/frieren 会跳过工作 alias（本 fork 的私有 secrets 仓库目前也没有这两个文件）。尚未合并的 0e124401 又把
    `nushell-secrets.nu` 移出了 agenix，下次合并时一并决定。
  - 上游 e8f80990 删除了 `modules/base/overlays.nix`
    中关闭 OpenLDAP 测试的覆盖，理由是 nixpkgs 已经跳过那些不稳定的测试。移植后 astra 的
    `modules.darwin.upstreamOpenldap` 变得多余，应注释掉，`tests/darwin-packages` 中
    `openldapUsesUpstream` 的期望值也要改为所有主机都是 `true`。
  - 上游 59f194f0 让 `just clean` 清除全部历史 generation，本地的 `justfile` 仍保留
    `--older-than 7d`。
- fern/frieren 的 `codex-app` cask 已被 Homebrew 停用（替代品为 `chatgpt` cask），上游仍在使用。
- 下次审查（`just upstream-darwin ryan/main`）需要注意：
  - 5e5707dd 让 Rime 在 Linux 和 macOS 间共享，并删除
    `home/darwin/rime-squirrel.nix`：`modules.desktop.squirrel`
    选项随之消失，astra 中的设置要注释掉；这一改动也与本地的 fcitx5 方案冲突。
  - 42641e2f 用 tuios 取代 zellij，并从 `home/darwin/terminal.nix` 中去掉 Alacritty 的字号设置。
  - d056aece 删除 `modules/darwin/nix-core.nix` 中 auto-optimise-store 的规避设置；astra 在
    `hosts/darwin-astra/default.nix` 中有自己的一份，要一起评估。
  - 1a10e652、0c8f0fe0、0e124401、3694961e 修改
    `secrets/darwin.nix`，以跟随上游私有 secrets 仓库的新布局。本 fork 的私有仓库结构不同，需要逐项对照后再决定。

## 常见问题

**GitHub HTTPS 拉取 git
input 失败**：用 SSH 预取同一修订，narHash 相同，之后求值会直接复用 store 中的路径：

```bash
nix flake prefetch 'git+ssh://git@github.com/<owner>/<repo>?rev=<rev>'
```

**拉取 eva 的合并后 astra 求值失败**：先运行 `just merge-audit` 检查合并有没有整个文件取一侧，再看
`just upstream-darwin` 列出的提交是否删除了 astra 使用的选项。
