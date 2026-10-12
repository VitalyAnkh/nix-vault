# 吸收上游改进

本仓库 fork 自 [ryan4yin/nix-config](https://github.com/ryan4yin/nix-config)。`vr`
是唯一的长期分支，所有主机都从它构建：eva（NixOS，上游 `idols-ai`
的继任主机）、muon（eva 的多用户变体）和 astra（macOS）。本文是吸收上游改进的固定流程。Darwin 的审查进度记录在
[`upstream-sync.toml`](./upstream-sync.toml)。

上游远程名为 `ryan`：

```bash
git remote add ryan git@github.com:ryan4yin/nix-config.git
git remote set-url --push ryan no_push # 防止误推
git fetch ryan main
```

## 原则

- **一次合并处理全部文件。**
  Git 按提交合并：合并之后，这些提交在 Git 看来都已合入，即使解决冲突时保留了本地版本，以后的合并也不会再带来被丢掉的改动。所以 Linux 和 Darwin 的文件要在同一次合并中处理，不能留给另一台机器“以后再合”。可以在 astra 上合并、在 eva 上验证 Linux 主机（见下文），也可以直接在 eva 上合并。
- **拿不准是否跟随的上游改动，由用户拍板。**
  这类改动包括：删除或替换用户在用的工具与功能，改变默认行为或界面，用便利换安全，以及用另一套方案取代本地方案。不要自行决定，也不要只按“本地没改过就跟上游”的合并规则带过。先查清三点：
  - 上游的理由（提交说明、PR、`WORKAROUNDS.md` 等）；
  - 有没有替代；
  - 在主机上的实际影响（实测现状，例如 sysctl 的当前值，不要只看配置）。

  然后列给用户讨论。定下结果后再改，并记入下文本次合并的表格。2026-10 的合并就是这样定下了 trusted-users、内核加固、Neovim、tuios、opencode2 和恢复哪些被删工具。

- **吸收上游的重构，前提是功能相当或更强。**
  共享模块跟随上游。主机相关的改进迁移到本地对应的主机：`idols-ai`/`ai`
  迁到 eva（再按需带到 muon），macOS 的改进迁到 astra。本地新增的主机都保留。
- **替代方案暂时不能工作时，放到本地开关后面。** 例如 mihomo 需要私有的订阅文件，eva 和 muon 就用
  `vr.proxy.backend` 暂时保留 Clash Verge，并写明切换步骤。
- **本地的定制要保留：**
  - fcitx5 与 `pkgs/` 中的 Rime 包。
  - `pkgs/` 中的 Emacs PGTK 构建和 Doom Emacs。
  - `pkgs/` 的包流水线（Nutstore 等）。
  - eva 和 muon 的启动、磁盘、文件系统与 preservation 设置。
  - eva 只用 NetworkManager。
  - Codex 用 pnpm 安装。

  Doom 配置中不再需要的设置注释掉，不要删除；其他随上游删除的工具和功能（例如 herdr、NetBird、nixvim）直接删除，不留注释。

- **逐文件三方合并。** 不要因为一侧有本地定制就整个文件取这一侧：另一侧不冲突的改动会一起丢失。
- **flake input 尽量用新的。** 冲突时逐个 input 取较新的一侧，合并后再
  `nix flake update`。某个 input 破坏了必须保留的本地构建时，只回退这个 input，并写明原因。
- **提交要清楚。** 保留 merge
  commit，不要 squash。对合并结果的修正按领域分成几个提交，提交说明写明原因。

## 日常纪律

- 每台机器开始工作前 `git pull --ff-only`，完成一组提交就推送。快进本地的 `vr`：在检出 `vr`
  的工作区运行 `git merge --ff-only <分支>`。`vr` 被任何工作区检出时，`git fetch . <分支>:vr`
  会被拒绝。
- 不在长期分支上积压改动。长期分支合入 `vr` 之前，先把最新的 `vr`
  合入该分支并验证：2026-10 合入的 astra 分支基于九月同步之前的
  `vr`，合并时多个文件整个取了一侧，事后才逐个补回。

## 合并流程

1. **准备。** 各机器先推送自己的提交，然后 `git fetch ryan main`，阅读双方自 merge
   base 以来的提交说明：

   ```bash
   git log --format='%h %ad %s%n%b' $(git merge-base vr ryan/main)..ryan/main
   git log --format='%h %ad %s%n%b' $(git merge-base vr ryan/main)..vr
   ```

2. **合并。** 在单独的 worktree 中执行 `git merge ryan/main`，逐处解决冲突：
   - `flake.lock` 按 input 取较新的一侧，不要整个文件取一侧。
   - 上游的 `Justfile` 对应本地的 `justfile`。用
     `git merge-file justfile <merge base 的 Justfile> <ryan 的 Justfile>` 三方合并，不留下
     `Justfile`。macOS 的文件系统不区分大小写，不要检出同时跟踪两者的提交。
   - `pkgs/_sources/generated.{json,nix}`
     只会在本地分支之间冲突。按源取较新的 pin，或者合并后重新运行 nvfetcher（见
     [pkgs/README.md](../pkgs/README.md)）。
   - 上游删除的模块：先用 `git grep 'modules\.<名字>\.'`
     找出主机中的设置，再决定迁移、删除还是保留。
3. **审计合并结果。**
   - `just merge-audit HEAD` 把合并结果与两个父提交的干净三方合并逐文件比较。
   - 合并之后又有修正提交时，审计最终的树：
     `just merge-audit --ours <合并前的 vr> --theirs ryan/main HEAD`。
   - 每个列出的文件都要看过：
     - `drops ... non-conflicting hunks`：解决冲突时取了一侧，同时丢掉了另一侧不冲突的改动，几乎总是错误。
     - `--diff`
       对需要三方合并的文件，显示从干净的三方合并到实际结果的差异；整个文件取一侧的情况不输出 diff。
     - 上游删除的文件不应再出现：
       `git diff --name-only --diff-filter=D $(git merge-base <合并前的 vr> ryan/main) ryan/main`
       列出的路径应不在 `HEAD` 中，有意保留的除外。
4. **对比主机。** `just host-diff <合并前的 vr> eva muon`（在 eva 上运行）和
   `just host-diff <合并前的 vr> astra`（在 astra 上运行）。它对比：
   - 启动、文件系统和 swap；
   - preservation；
   - 网络；
   - secrets 及 `/etc/agenix`；
   - 系统服务与软件包；
   - 各用户的 Home Manager 文件和环境变量。

   每处差异都要能用合并中的提交解释。预期之外的差异就是需要修正的地方。

   - 列出要用户决定的上游改动（见“原则”），每一项都附上上游理由、替代方案和实测影响，讨论出结果再改。

5. **验证。**
   - `just test`（`evalTests` 也包含 Darwin 主机的测试）。
   - 构建 eva 和 muon：`nix build --max-jobs 8 --cores 8 --no-link .#nixosConfigurations.<主机>.config.system.build.toplevel`。
   - 构建 astra：
     `nix build --no-write-lock-file --max-jobs 8 --cores 8 --out-link result-astra .#darwinConfigurations.astra.system`。
   - nixpkgs 更新后，检查 `pkgs/` 中覆盖 nixpkgs 的包和手动固定的包（见
     [pkgs/README.md](../pkgs/README.md#手动固定的包)）。
   - 确认 Emacs、fcitx5/Rime、Nutstore 等本地包能求值和构建。
   - 新文件要先 `git add`，flake 才看得到。
6. **审查 Darwin 路径。** 见下文“审查 Darwin 改动”，然后更新 `darwin.reviewed`。
7. **提交和推送。** 快进 `vr` 并推送，其它机器 `git pull --ff-only`。
8. **激活。** 激活另行决定，只在用户明确要求时进行：
   - eva、muon：`nixos-rebuild switch`；
   - astra：按 [astra 文档](./astra-macos-host.md)操作。

## 在 astra 上合并，在 eva 上验证

astra 能拉取两个远程、求值 Darwin 主机，适合做合并。eva 的配置依赖 IFD 和 x86_64-linux 构建，在 astra 上求值很慢，还常常失败，所以 Linux 主机的求值和构建都放到 eva 上，经 Tailscale
SSH 完成。

1. **建立复用的 SSH 连接。** 只需认证一次：

   ```bash
   mkdir -p /tmp/nv-ssh && chmod 700 /tmp/nv-ssh
   ssh -o ControlMaster=yes -o ControlPath=/tmp/nv-ssh/eva -o ControlPersist=yes -fN <用户>@eva
   eva() { ssh -o ControlPath=/tmp/nv-ssh/eva -o BatchMode=yes <用户>@eva "$@"; }
   eva-git() { GIT_SSH_COMMAND='ssh -o ControlPath=/tmp/nv-ssh/eva -o BatchMode=yes' git "$@"; }
   ```

   只让访问 eva 的 git 命令用 `eva-git`：ControlPath 里没有主机名，导出 `GIT_SSH_COMMAND`
   会把推送到 GitHub 的操作也送到 eva 上。

   主机名用 Tailscale 的名字（`tailscale status`
   可查）。不要把密码写进任何文件。需要密码登录时，通过环境变量交给 `sshpass -e`，只用一次。

2. **取回 eva 上进行中的工作（如果有）：**

   ```bash
   eva-git fetch ssh://<用户>@eva/~/nix-vault vr:refs/remotes/eva/vr
   ```

   eva 上已有别人（或其他 agent）做的合并时，把它当作待审计的输入：先读会话中用户的原话，那里写着这次合并要达成什么；再按“审计合并结果”逐个文件检查。

3. **在 astra 的独立 worktree 中合并：**

   ```bash
   git worktree add /tmp/nv-merge -b merge/ryan vr
   cd /tmp/nv-merge && git merge ryan/main
   ```

4. **推到 eva 的独立分支，在 eva 上用单独的 worktree 验证。** 不要动 eva 自己的
   `~/nix-vault`：那里可能有未提交的改动，或者正在运行的 agent 会话。被检出的分支不能被推送覆盖，所以推到
   `merge-incoming`，验证 worktree 检出自己的分支 `merge-verify`，每轮重置到推送的提交：

   ```bash
   eva-git push --force ssh://<用户>@eva/~/nix-vault merge/ryan:refs/heads/merge-incoming
   eva 'git -C ~/nix-vault worktree add -b merge-verify ~/nix-vault-merge-verify merge-incoming' # 第一次
   eva 'cd ~/nix-vault-merge-verify && git reset --hard merge-incoming'                       # 之后每轮
   eva 'cd ~/nix-vault-merge-verify && just test && just host-diff <合并前的 vr> eva muon'
   ```

5. **构建。** 构建在 eva 上后台运行，日志写到 `/tmp`，限制为
   `--max-jobs 8 --cores 8`。构建期间不要在 eva 上再启动其它求值或构建：

   ```bash
   eva 'cd ~/nix-vault-merge-verify && nohup nix build --max-jobs 8 --cores 8 --no-link --keep-going \
     .#nixosConfigurations.eva.config.system.build.toplevel > /tmp/eva-build.log 2>&1 &'
   ```

   - `nix flake update` 在哪台机器上运行都可以。在 eva 上运行时，把 `flake.lock` 拷回 astra 再提交。
   - 经 SSH 在 eva 上更新时，私有的 `mysecrets`
     无法非交互地拉取：git 会改用 HTTPS，并在 eva 的桌面上弹出凭据对话框。所以更新时排除它，并禁止弹窗。
   - eva 直连时 `github.com` 经常连不上，`api.github.com` 和 `codeload.github.com`
     却正常。Nix 配了 GitHub token 后，`github:`
     input 改从 API 的 tarball 地址下载。token 只放在环境变量里，不要写进文件：

     ```bash
     inputs=$(nix flake metadata --json | jq -r '.locks.nodes.root.inputs | keys[]' | grep -v -x mysecrets)
     export NIX_CONFIG="access-tokens = github.com=$(gh auth token)"
     GIT_TERMINAL_PROMPT=0 SSH_ASKPASS_REQUIRE=never nix flake update $inputs
     ```

     `mysecrets` 在 astra 上用 `just upp mysecrets` 单独更新。

   - 有些源码只能经代理下载，例如 nixpkgs 的 WeChat 来自 web.archive.org。构建前在 eva 上打开 Clash
     Verge（TUN 模式），换成 mihomo 后则由 mihomo 负责。
   - eva 上的 Clash
     Verge 没有开启 IPv6：TUN 模式下 DNS 只返回 IPv4 地址，只能经 IPv6 访问的替代源每次查询都要重试到超时，构建明显变慢。2026-10 时的 SUSTech 镜像就是这样，eva 上 2026-08 的旧系统还在
     `substituters` 中列着它（新配置已经没有）。这时用 `--option substituters '…'`
     把它去掉再构建；eva 的用户在 `trusted-users` 中，可以这样覆盖。
   - astra 上对 astra 做同样的验证。

6. **收尾。** 构建都通过后，在 astra 上快进 `vr` 并推送。eva 的 `~/nix-vault` 在没人使用时再
   `git pull --ff-only`。然后清理：

   ```bash
   eva 'git -C ~/nix-vault worktree remove ~/nix-vault-merge-verify && git -C ~/nix-vault branch -D merge-verify merge-incoming'
   git worktree remove /tmp/nv-merge && git branch -D merge/ryan
   ssh -O exit -o ControlPath=/tmp/nv-ssh/eva <用户>@eva
   ```

## 审查 Darwin 改动

合并时 Darwin 文件也已三方合并。这一步按路径复查，确认没有遗漏上游的改动，或者把取舍写下来。

1. `just upstream-darwin` 列出 `darwin.reviewed` 之后、已合入 `HEAD` 的上游提交中修改了
   `darwin.paths` 的部分。加参数 `ryan/main` 还会列出尚未合并的提交。逐条用 `git show <提交>`
   阅读改动和提交说明。
2. 对 `darwin.paths` 中的路径运行 `git diff ryan/main HEAD -- <路径>`，把每处差异归为三类：
   - (a) 上游的改动没有被采纳：移植。
   - (b) 本地有意的定制：保留。
   - (c) 上游的改进但与本地约定冲突：不移植，在代码注释或下文“有意保留的差异”中写明原因。

   只看提交列表不够：merge base 过旧时，文件可能整个停留在旧版本。2026-04 的 61aed7c6 合并的 merge
   base 是 2023 年的提交，合并时原样保留了 vr 一侧的
   `modules/darwin/apps.nix`。上游 2025-11 到 2026-04 间对它的修改都没有进来，之后的合并也不会再带来。

3. Homebrew 条目先核对是否已删除、改名或停用，可以查 formulae.brew.sh 的 API（`https://formulae.brew.sh/api/formula/<名字>.json`、`.../api/cask/<名字>.json`）和 homebrew-cask 的提交历史。注意：
   - Homebrew 6 默认要求信任 tap，nix-darwin 对全限定名（`<用户>/<tap>/<名字>`）的条目默认信任。
   - fern/frieren 使用 `cleanup = "zap"`：清单中删除或注释掉的条目，会在下次激活时被卸载并清除数据。
   - astra 使用 `cleanup = "check"`：有未声明的包时，激活中止。
4. 验证 astra、fern、frieren 的 `system.drvPath` 并构建 astra，然后把 `darwin.reviewed`
   改为审查到的上游提交，在提交说明中写明。

## 2026-10 的合并

Codex 先在 eva 上合并了 ryan/main
f32d67a5（93700824）。之后在 astra 上把它与 vr 合并（78d4ade4），再合入 9c388195（dfa4a0b1），审计、修正，并在 eva 上验证。审计发现的问题，以后的合并要注意：

- 36 个冲突文件整个取了一侧，其中 23 个因此丢掉了另一侧不冲突的改动，例如编辑器环境变量和终端设置。`just merge-audit`
  现在会标出这种情况。
- 主机配置中出现双方都没有的改动：
  - eva 改用 systemd-networkd；
  - swapfile 写成 96 GiB 并带 `size`：激活时 NixOS 会删掉 eva 现有的 64 GiB swapfile，再按 96
    GiB 重建，而磁盘只剩约 80 GiB；
  - disko 布局使用默认分区标签，与 eva 的磁盘对不上；
  - 本地 `hosts/{eva,muon}/mihomo.nix` 被删除；
  - mihomo 的 README 写成在 eva 上启用。
- 13 个 flake input 比上游旧。
- 换 mihomo 时，上游删掉了 `clash-verge.desktop`
  登录自启项。用选项保留被替换的功能时，上游一并删掉的配套设置也要保留。

### 吸收的上游重构

| 上游改动                                                               | 本地结果                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ---------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| zellij 改为 tuios（#349）                                              | 删除 zellij。tuios 不自动启动，与原来 zellij 的用法一致；leader 键改为 Ctrl+Z（原 zellij 的解锁键），避开 Emacs 的 C-b                                                                                                                                                                                                                                                                                                                                                              |
| Clash Verge 改为原生 mihomo                                            | 新增 `vr.proxy.backend`（`hosts/eva/proxy.nix`），默认仍为 `clash-verge`，此时保留 Clash Verge 的登录自启；切换步骤见下文                                                                                                                                                                                                                                                                                                                                                           |
| 删除 NetBird                                                           | 删除，由 Tailscale 覆盖；preservation 中的状态目录和 muon 的单元覆盖一并删除，状态数据留在 `/persistent`                                                                                                                                                                                                                                                                                                                                                                            |
| ai 主机的 disko                                                        | `hosts/eva/disko-fs.nix` 只供重装使用（`disko.enableConfig = false`），与 eva 的磁盘一致：by-id 路径、分区标签 ESP/primary、ESP 大小和子卷都相同                                                                                                                                                                                                                                                                                                                                    |
| ai 主机的 swap（磁盘 swapfile + zswap，不用 zram）                     | eva 使用 `@swap` 上已有的 64 GiB swapfile；muon 的 swapfile 未核实，仍用 zram                                                                                                                                                                                                                                                                                                                                                                                                       |
| ai 主机的 NVMe APST 参数                                               | 不迁移：上游 `WORKAROUNDS.md` 的 WA-008 只针对它自己那块硬盘                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ai 主机的 networkd 与 resolvectl DNS 接管                              | 不迁移：eva 只用 NetworkManager，没有 systemd-resolved；mihomo 的 TUN 自己劫持 DNS                                                                                                                                                                                                                                                                                                                                                                                                  |
| ai 主机的 smartd、CanoKey、WiVRn                                       | 迁到 eva；WiVRn 不自动启动（`just vr`）                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ai 主机针对 tmpfs 根的状态修复（#348、d9208f49）                       | 采用：持久化 `/var/lib/cups` 和 `/var/lib/logrotate`（logrotate 的状态写在其中），开机清空 `/var/lib/systemd/coredump`；另按上游持久化 `.config/go-musicfox`，`~/.android` 改为 0700。muon 导入 eva 的 preservation，同样生效。eva 的 `/var/lib/cups` 里没有打印机配置，不用迁移；切换 muon 前，若它的 `/var/lib/cups/printers.conf` 存在，先复制到 `/persistent/var/lib/cups`                                                                                                      |
| 内核加固（#365，`hardening/kernel-hardening.nix`）                     | 采用。eva 上实际变化的只有 `fs.protected_fifos`/`fs.protected_regular`（1→2）、`kernel.kptr_restrict`（1→2）和 `net.core.bpf_jit_harden`（0→1）；`ptrace_scope=1`、`dmesg_restrict=1` 等原本就是内核默认值                                                                                                                                                                                                                                                                          |
| 用户不再属于 libvirtd 等等价于 root 的组（#335）                       | 采用；eva 没有启用 libvirtd，这个组成员关系原本就不起作用                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 去掉 virtualisation 模块（VFIO、QEMU，#332）                           | 采用；eva 没有用到 VFIO。Flatpak 由本地的 `modules/nixos/desktop/misc.nix` 保留                                                                                                                                                                                                                                                                                                                                                                                                     |
| agents 模块（#367）                                                    | 采用，但 rules 和 skills 默认关闭（`modules.agents.globalRules.enable`、`modules.agents.skills.enable`）：这些主机的 `~/.codex/AGENTS.md` 和 `~/.agents/skills` 由用户和 oh-my-codex 管理                                                                                                                                                                                                                                                                                           |
| 编辑器环境变量统一在 `modules/base/packages.nix`（`SUDO_EDITOR = hx`） | 采用                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Neovim 从 nixvim 改为 `programs.neovim`（#336）                        | 采用；去掉 nixvim input 和 astra 的 26.05 包集设置。Catppuccin 只为 Neovim 开启（`theme.nix` 中 `autoEnable = false`，Zed 不受影响）                                                                                                                                                                                                                                                                                                                                                |
| opencode 改为 opencode2（01ed0aa5）                                    | 采用                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| #332 删除"用不到"的工具                                                | 本地没改过的行跟随上游删除。本地改过的列表（`home/base/core/core.nix`、`home/base/tui/dev-tools.nix`、`home/base/tui/editors/packages.nix`、`home/linux/gui/base/creative.nix`、`modules/base/packages.nix`）在冲突中保留了本地条目，hydra-check、nix-init、cowsay、tokei、inkscape、procs、wget 等因此仍在。按用户决定保留容器/K8s/云工具：lazydocker、kubebuilder、clusterctl、kubectl-tree、go-containerregistry、ko、eksctl、ssm-session-manager-plugin、google-cloud-sql-proxy |
| 删除 OpenLDAP 测试覆盖（e8f80990）                                     | 采用：删除 `modules/base/overlays.nix` 和独立 HM 中的覆盖，以及随之多余的 `modules.darwin.upstreamOpenldap` 选项                                                                                                                                                                                                                                                                                                                                                                    |
| 删除 foot 和 Alacritty，终端只留 ghostty 和 kitty（#349）              | 采用；eva 登录时自启 ghostty 和 kitty                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Qt 平台主题改为 `xdgdesktopportal`（9cc5d924）                         | 采用：Qt 应用跟随系统深浅色；字体仍是 Qt 内置的 Sans Serif 9                                                                                                                                                                                                                                                                                                                                                                                                                        |
| plocate 全盘文件名搜索（#333、#356）                                   | 采用；eva 和 muon 不持久化 `/var/cache`，数据库在内存里，重启后要等下一次定时扫描                                                                                                                                                                                                                                                                                                                                                                                                   |
| 删除 PipeWire 的 JACK 支持（#357）                                     | 采用；eva 上没有只能用 JACK 的程序                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 删除 herdr（#374）                                                     | 采用；eva preservation 中的 herdr 目录一并删除                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| WeChat 改用 nixpkgs-master 的包（a1ec97d3，WA-007）                    | 采用。nixpkgs 从 web.archive.org 下载 AppImage，eva 直连时连不上，构建前要打开代理                                                                                                                                                                                                                                                                                                                                                                                                  |

### 有意保留的差异

| 路径                                                                             | 类别 | 原因                                                                                                                         |
| -------------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------- |
| `home/linux/gui/base/fcitx5`、`pkgs/fcitx5`                                      | b    | 本地的 fcitx5 与 Rime 包；不采用上游共享的 `home/base/gui/rime`（5e5707dd）                                                  |
| `home/darwin/rime-squirrel.nix`                                                  | c    | 上游 5e5707dd 删除了它，改用共享的 Rime 模块；本地保留自己的方案                                                             |
| `home/base/core/theme.nix`                                                       | b    | Catppuccin 只用于 Neovim（`autoEnable = false`），其余程序保持各自的主题                                                     |
| `modules/base/nix.nix`                                                           | b    | 用户决定保留 `trusted-users`；上游 #335 出于安全考虑删除了它                                                                 |
| `home/base/tui/agents/packages.nix`                                              | b    | 本地的 agent CLI 列表；dsh 用 llm-agents 的构建（上游用 nur-ryan4yin 的 shim）；Codex 用 pnpm 安装                           |
| `home/base/tui/container.nix`、`home/base/tui/cloud`                             | b    | 按用户决定保留上游 #332 删除或注释掉的容器、K8s 与云工具                                                                     |
| `home/base/tui/tuios/config.toml`                                                | b    | leader 键为 Ctrl+Z                                                                                                           |
| `justfile` 的 `clean`                                                            | b    | 保留 `--older-than 7d`，不像上游 59f194f0 那样清除全部历史 generation                                                        |
| `home/darwin/shell.nix`                                                          | c    | 上游 6218bb22 把 Homebrew 放到 PATH 最前；本地追加在后，使 Nix 包优先于 Homebrew，astra 的 PATH 顺序依赖这一点               |
| `home/darwin/ssh.nix`                                                            | c    | 上游 b44d2770 改用系统级 SSH 配置并删除此文件；独立 HM 输出 `vitalyr@aarch64-darwin` 不经过 nix-darwin，主机别名只能来自这里 |
| `home/darwin/default.nix`                                                        | b    | Home Manager 26.05 在 Darwin 上默认 `programs.man.package = null`，因此关闭 man 缓存                                         |
| `home/darwin/proxy`                                                              | b    | 加了启用开关；proxychains 的链接指向 `repoRoot` 下的仓库，而不是上游的 `~/nix-config`                                        |
| `home/darwin/karabiner`、`home/darwin/input-source-pro`、`home/darwin/README.md` | b    | astra 的键位与输入法                                                                                                         |
| `modules/darwin/{overlays,nix-daemon,system-paths}.nix`                          | b    | 所有 Darwin 主机共用的本地模块                                                                                               |
| `modules/darwin/README.md`                                                       | b    | 文案                                                                                                                         |
| `secrets/darwin.nix`、`secrets/nixos.nix`                                        | b    | 私有 secrets 仓库的布局与上游不同（1a10e652 等）；secret 文件不存在时跳过，astra、eva 和 muon 的 secrets 合并前后相同        |
| `home/hosts/darwin`、`hosts/darwin-astra`、`outputs/aarch64-darwin`              | b    | astra 主机、fern 的 Emacs、独立 HM 输出与 eval 测试                                                                          |

### 其他修正

- 按用户决定删除未导入的 `hosts/{eva,muon}/mihomo.nix`（2025 年的 mihomo 开关）和
  `hosts/muon/preservation.nix`（已被 eva 的 preservation 取代）。
- muon 的 `disabledModules` 原来写成字符串，按 nixpkgs 的模块目录解析，从未禁用共享的
  `modules/nixos/base/user-group.nix`。改为路径后，muon 的用户和组只来自
  `hosts/muon/users.nix`：fish 照旧开启，muon 用不到的 `fileshare`
  组随之去掉，root 的 SSH 公钥不再重复列出。

### 切换到 mihomo

1. 写好私有的订阅文件：

   ```bash
   mkdir -p ~/.config/mihomo
   cp modules/nixos/desktop/networking/mihomo/sources.example.yaml ~/.config/mihomo/sources.yaml
   chmod 600 ~/.config/mihomo/sources.yaml
   $EDITOR ~/.config/mihomo/sources.yaml   # secret、private_domains、providers
   ```

2. 在 `hosts/eva/default.nix`（muon 同理）中设置 `vr.proxy.backend = "mihomo";`，构建并切换。Clash
   Verge 停止；mihomo 服务此时因为还没有配置而无法启动，这段时间没有代理。
3. `just mihomo-gen` 生成并校验 `~/.config/mihomo/config.yaml`，然后
   `sudo systemctl restart mihomo.service`。控制面板在 `http://127.0.0.1:9090/ui`。
4. 确认 `curl -I https://github.com` 和 `git ls-remote` 都正常。不行就把 backend 改回
   `clash-verge`，再切换一次。

### 待处理

- 工作 alias：本地仍用
  `/etc/agenix/alias-for-work.nushell`（`secrets/nixos.nix`）。上游 0e124401 改为不经 agenix 的
  `~/.secrets/nushell-secrets.nu`，未采用；私有仓库目前没有这两个文件。
- fern/frieren 的 `codex-app` cask 已被 Homebrew 停用（替代品为 `chatgpt` cask），上游仍在使用。
- 切换到 mihomo（见上文），需要先准备 `sources.yaml`。
- contour、Cataclysm DDA 和 Warzone 2100 暂用 nixpkgs
  26.05 的包（`modules/nixos/base/ssh.nix`、`home/base/gui/games.nix`）：unstable 改用 GCC
  16 后编译不了它们，缓存里也没有。unstable 能构建后改回。

## 常见问题

**GitHub HTTPS 拉取 git
input 失败**：用 SSH 预取同一修订，narHash 相同，之后求值会直接复用 store 中的路径。`shallow=1`
只拉取这一修订，比拉取完整历史快得多：

```bash
nix flake prefetch 'git+ssh://git@github.com/<owner>/<repo>?rev=<rev>&shallow=1'
```

**eva 上求值卡在 `git ls-remote`**：`builtins.fetchGit`（例如 Warp 的 Cargo
git 依赖）缓存的 ref 过期后（默认一小时）要重新查询远程的 HEAD。github.com 不通时，每个查询要等两分多钟才超时，然后改用过期的缓存。求值期间可以结束运行超过 15 秒的查询，效果相同：

```bash
while sleep 5; do
  ps -eo pid=,etimes=,args= | awk '$3 == "git" && $4 == "ls-remote" && $2 > 15 && /github\.com/ {print $1}' | xargs -r kill
done
```

**在 astra 上求值 eva 失败**：eva 的配置用到 IFD（例如 codex-desktop-linux、Warp 的源码），需要 x86_64-linux 构建。改到 eva 上求值。

**拉取合并后 astra 求值失败**：先运行 `just merge-audit <合并提交>`（合并后又有修正提交时，用上文的
`--ours`/`--theirs` 形式），检查合并有没有整个文件取一侧；再看 `just upstream-darwin`
列出的提交是否删除了 astra 使用的选项。
