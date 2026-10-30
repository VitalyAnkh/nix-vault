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
   - 逐个核对上游中涉及 ai 主机的提交：`git log --format='%h %s' <merge base>..ryan/main -- hosts/idols-ai home/hosts/linux/idols-ai.nix outputs/x86_64-linux/src/idols-ai.nix`。每个提交要么已在 eva 上生效（迁移过来，或经共享模块自动生效），要么不适用于 eva，要么在下文的合并表格中记录了用户的决定；其余的都要问用户。只看冲突和主机差异会漏掉 eva 从未跟随的改动。

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
   - eva、muon：`nixos-rebuild boot` 后重启；内核、驱动、防火墙或挂载有变化时不要在线 `switch`；
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
     Verge（TUN 模式），换成 mihomo 后则由 mihomo 负责。Go 包的依赖来自 proxy.golang.org，也要代理，另见“常见问题”。
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
f32d67a5（93700824）。之后在 astra 上把它与 vr 合并（78d4ade4），再合入 9c388195（dfa4a0b1），审计、修正，并在 eva 上验证。最后合入的 bac43e0e（3bb8cf81）只改了上游 mihomo 的 README 和网关脚本，主机配置不变。审计发现的问题，以后的合并要注意：

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
- 第一轮审查只看了冲突和主机差异，漏掉了 eva 本应跟随或需要用户决定的 ai 改动：vinput、上游删除的 agent
  CLI、Lutris/umu、Steam 的 gamescope 会话、#348 的其余部分、ctx7 的旧目录，以及更早的 binfmt 静态模拟器。按提交逐个核对（见合并流程第 4 步）之后才找出来。

### 2026-10-15：合入 b4dae701

在 astra 上合并（0006492d），在 eva 上验证。上游这一段主要是 Ryan 自己的主机：aquamarine 作为双 GPU 推理主机重新启用，ai 换回 MSI
B760M 主板、只剩 RTX 4090，并改为按 `en*`
前缀匹配网卡。共享部分有 mihomo 的 DNS 与网关修复、colmena 改为在目标主机上构建（已并入
`justfile`），以及 vinput 从 v2.4.0 升到 v2.4.2（eva、muon 使用）。逐个核对 ai 的提交后，没有需要迁到 eva 的改动：eva 早已使用 ai 现在改用的 NVENC
Sunshine 设置，只有一块 GPU，用 NetworkManager 而不是 networkd；ai 把用户加入 render 组是为 Intel
NPU 上的语音识别，eva 的 vinput 经 `/dev/nvidia*`
使用 GPU。上游没有改 Darwin 路径，`darwin.reviewed` 推进到 b4dae701。上游新增的 `idols-ai-net`
测试求值 `ai-niri`，本地不构建 ai，因此删除。

### 2026-10-26：合入 b334336c

在 astra 上合并（6463d716），在 eva 上验证。上游这一段有 73 个提交。共享部分：TuneD 改为内核自己的 CPU 调频（#461），vinput 的配置放进仓库（#445），dsh 改为只用 Nushell（#473、#475、#476），colmena 节点改从
`nixosConfigurations` 重建（WA-042），k3s 的 MicroVM 客体直接运行 `nixosConfigurations`
中的系统（#483），新测试要求 exporter 绑定局域网地址，根证书黑名单（WA-040，合并后随 input 更新删除），yazi 插件（#469），以及 hypridle 检测手柄和媒体播放。其余是 Ryan 自己的主机：aquamarine 在 NPU 上运行 Whisper（只有它用新增的
`nixpkgs-npu` input），ai 新增 DDC/CI、OpenRGB 和主板传感器。

合并之前，astra 主检出中有 10-16 到 10-19 的未提交改动：nvfetcher 源更新、astra 改用 Xcode 的编译器、Bevy 模板。astra 第 13 代和 eva 第 283 代就是用这些改动构建的。按用户决定，把它们拆成三个提交，接在合并之后。

需要用户决定的改动，结果都记在下表中（2026-10-26）。逐个核对 ai 的提交后，以下改动不适用于 eva：

- `neighbour-probe.nix`（WA-035）：针对 ai 的 Mesh WiFi 回程；
- `modules.remote-builders.enable`：经 aquamarine 构建；
- `~/models` 的持久化；
- swapfile 从 96G 改为 32G；
- niri 的显示器模式；
- nvidia-gpu exporter 绑定局域网地址：eva 没有这个 exporter；
- ai 的 OpenRGB 持久化：eva 有自己的条目。

上游测试中的主机按本地情况改写：`cpu-power` 用 eva、muon 代替 `ai-niri`；`cpu-power` 和
`microvm-guest-parity` 在 youko 不存在时跳过它（youko 需要私有 secrets）；aarch64 的 `cpu-power`
中，shoukei 没有 `my-asahi-firmware` 时 Asahi 模块关闭，调频器是 `powersave` 而不是
`schedutil`。上游修改的 Darwin 路径只有 conda 的删除和文档，`darwin.reviewed` 推进到 b334336c。

在 eva 上验证时发现并修正：

- muon 的 `preservation-users.nix` 把 eva 的 `preservation.nix` 当作函数调用，后者新增
  `config`、`lib` 参数后 muon 无法求值。迁移提交中一并修正，并在 eva 的文件开头注明这个调用。
- 关闭 exporter 后，`monitoring.nix`
  仍让两个单元排在 network-online.target 之后，留下没有命令的单元，所以合并提交把它们屏蔽。
- tuios v0.10.1 的 Go 依赖要从 proxy.golang.org 下载，eva 直连不通，见“常见问题”。

合并之后单独更新了 flake
input（11a307ac）：nixpkgs 到 2026-10-23（3ec63636），nixpkgs-darwin 到 2026-10-24（674a2028），nixpkgs-stable、nixpkgs-master、home-manager、nix-darwin、preservation 等到 10 月下旬。nix-darwin 没有改动 Homebrew 和激活。新的 nixpkgs 删除了
`boot.initrd.systemd.enable`：systemd
initrd 已是唯一的 initrd，仍设置这个选项的配置在构建时断言失败（eval 测试不检查断言，所以测试仍然通过）。同一提交删掉了 eva（muon 共用）、ai、aquamarine 和 shoryu 的 preservation 中的这一行，它们的 initrd 不变；preservation 也随之去掉了对应的断言。`scripts/host-facts.nix`
用 `tryEval`
读取这个选项，host-diff 因而仍能比较更新之前的版本。同一提交还删除了上游的 WA-040（`modules/base/security.nix`
的根证书黑名单）：更新后 nixpkgs 的 `nixos/modules/security/ca.nix` 和 nix-darwin 的 `security.pki`
已自行把“Comodo AAA Services root”列入黑名单，NSS
3.131.1 也直接删除了三个 emSign 根证书；黑名单中写着证书包里已不存在的证书时，cacert 的构建会失败，所以保留本地的列表会让所有主机的 nss-cacert 构建失败。删除后被拒绝信任的根证书与之前相同，WA-040 已满足它自己写明的删除条件。本地的 udisks
overlay（3d7ce5b5）也一并删除：它因为 udisks
2.11.1 在本地构建 gtk-doc 和检查失败而关掉了这两项；现在 nixpkgs 的 2.11.2 已由 Hydra 带着这两项构建并缓存，保留 overlay 只会让 udisks 和依赖它的包（包括 udiskie，它的 keyring 测试在 eva 的构建沙箱中失败）都在本地重新构建。随后检查手动固定的包（7d97d1e8、68f6ac23、3d9c7194、2010e0d9）：

- unstable 的 contour 已在缓存中，改回 unstable。
- unstable 的 Zotero 10.0.4 改用二进制的 Firefox ESR 140.17.0，比固定的 10.0.2 新。ESR
  140 已于 2026-10-13 停止安全更新，nixpkgs 因此把这个 Firefox 标为不安全，拒绝求值。固定的 10.0.2 内置 Gecko
  140.16.0，同样停止支持，而且少一版安全修复；Zotero 10 本身面向 ESR
  140，目前没有基于受支持内核的 Zotero。用户决定（2026-10-26）改用 10.0.4：`vars/default.nix` 的
  `permittedInsecurePackages` 只放行
  `firefox-esr-140-bin-unwrapped-140.17.0esr`，NixOS、nix-darwin 和独立 Home
  Manager 的 nixpkgs 配置都读取它（fern、frieren 和独立配置也装 Zotero），并删除 `nixpkgs-zotero`
  input。这个 Firefox 不在缓存中，Zotero 在本地构建，不编译 Firefox。
- Warzone 2100 和 Cataclysm DDA 在 unstable 中仍没有缓存，继续用 26.05。
- zed-editor-bin 从 1.23.2 升到 Zed 最新的稳定版 1.25.3：更新后 nixpkgs-darwin 的 zed-editor 是 1.25.3，astra 的 eval 测试要求本地固定的官方版本不旧于它。
- 按用户决定，其余手动固定的包也升到最新版：computer-use-linux 0.7.27 和 cua-driver
  0.38.0（只有 kana、ruby 使用），Darwin 上的 JetBrains Toolbox 3.9.0.88839，以及 Godot 用的 OpenXR
  loader（OpenXR-SDK-Source 1.1.65）。Android cmdline-tools 已是最新版。
- astra 构建打了补丁的 Node 24.21.0 时，inspector 测试因 127.0.0.1:9444 被一个带
  `--remote-debugging-port=9444`
  的 Chrome 占用而失败（Darwin 的构建与本机共用网络）。这个 Node 只因 f5d50079 的 V8 补丁才需要本地构建，上游的构建已在缓存中。按用户决定（2026-10-27）删除
  `pkgs/nodejs` 和只为它服务的
  `modules/darwin/overlays.nix`，改用 nixpkgs 的 Node（2010e0d9）。nixpkgs-darwin 现已缓存 Wrangler
  4.151.1，当初需要这个补丁的 Wrangler 构建也不再在本地进行。Node 24.21.0 自带的 V8 仍有这个问题，见
  [astra 文档](./astra-macos-host.md)。

### 2026-10-30：合入 def7d8f7

在 astra 上合并（eef0d345），在 eva 上验证。上游这一段有 12 个提交：nixpkgs 和 nixpkgs-darwin 更新到 e62746b（2026-10-28），Avahi 的发布设置随之改为
`settings.publish`（eva 生成的 `avahi-daemon.conf` 与之前完全相同），gitea 改用
`ROOT_URL`；删除 WA-002（helm 不再取自 nixpkgs 25.05）和 WA-003（lanzaboote
v1.2.0 不再需要让它的 rust-overlay 跟随本仓库）；tuios 升到 v0.11.1、ponytail 升到 v5.3.3，pyclipsync 改跟 main；Nushell 开启
`loadSessionVariables`；重新加入 gitleaks；nvidia
exporter 排到 network-online.target 之后；agents 规则的补充；niri 的 Steam 窗口规则（还没设标题的 Proton 窗口也全屏，ai 的输出按需开启 VRR）；删除 VS
Code；私有 secrets 仓库的规则文件改名为
`agenix-rules.nix`。需要用户决定的改动，结果记在下表中（2026-10-30）。

逐个核对 ai 的提交：preservation 中 `boot.initrd.systemd.enable` 一行，eva 已在 11a307ac 中删除；VS
Code 按用户决定保留；按需 VRR 不迁移：eva 的桌面是 GNOME，它的 niri 输出配置只设缩放和位置，而共享的窗口规则只在输出设置了
`variable-refresh-rate on-demand=true` 时起作用，是否开启 VRR 取决于 eva 的显示器。

其余的处理：

- 根证书黑名单：上游 e8e9691f 只保留 "Comodo AAA Services
  root"，理由是 nix-darwin 只把列表原样传下去。锁定的 nix-darwin（bb0b90db）其实会自己加上这一项，NixOS 的
  `ca.nix` 也一样，astra 的证书包中这个根证书被标为不受信任。本地仍不设黑名单，见“有意保留的差异”。
- shoryu 的 preservation 改用上游的版本：vr 中的是上游 1222bb25（2026-02，收紧家目录权限）之前的旧版，是早先的合并留下的。
- 私有 secrets 仓库仍用 `secrets.nix`：agenix
  0.18 还能找到它，但会提示这种用法已弃用，见“待处理”。`secrets/README.md` 保留本地的写法。

在 eva 上验证时发现并修正：合并最初跟随上游删除了 `rust-overlay` input，eva 上的 `just test`
因此求值失败。本地的 `pkgs/warp-terminal`
调用 Warp 上游的 flake，要把 crane 和 rust-overlay 传给它（经
`modules/base/overlays.nix`），所以合并提交保留这个 input。

合并之后更新了 flake input（57e96049）。astra 从 GitHub 下载太慢，改在 eva 上运行，再把 `flake.lock`
拷回 astra。两台机器下载 nixpkgs 的 tarball 时都偶尔报
`Truncated tar archive`，原因是下载中途超时，重试即可。

- nixpkgs 保持上游锁定的 e62746b0（2026-10-28），与 nixpkgs-darwin 相同。`flake.nix`
  中它跟随 nixos-unstable，而这个分支还停在 31ecbaca（2026-10-27），直接更新反而会退回旧版本。
- llm-agents 更新到 2026-10-30：按用户决定，dsh 从 0.2.1-rc.4 升到 rc.5，codex 升到 0.166.0，opencode2 升到 2.2.2。
- 其余更新的有 firefox（nightly）、microvm、nixpkgs-master、nur-ryan4yin、rust-overlay、winapps 和 xremap-flake。

### 吸收的上游重构

| 上游改动                                                                                              | 本地结果                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| ----------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| zellij 改为 tuios（#349）                                                                             | 删除 zellij。tuios 不自动启动，与原来 zellij 的用法一致；leader 键改为 Ctrl+Z（原 zellij 的解锁键），避开 Emacs 的 C-b                                                                                                                                                                                                                                                                                                                                                              |
| Clash Verge 改为原生 mihomo                                                                           | 新增 `vr.proxy.backend`（`hosts/eva/proxy.nix`），默认仍为 `clash-verge`，此时保留 Clash Verge 的登录自启；切换步骤见下文                                                                                                                                                                                                                                                                                                                                                           |
| 删除 NetBird                                                                                          | 删除，由 Tailscale 覆盖；preservation 中的状态目录和 muon 的单元覆盖一并删除；eva 上留在 `/persistent` 的状态数据已按用户要求删除（2026-10-13）                                                                                                                                                                                                                                                                                                                                     |
| ai 主机的 disko                                                                                       | `hosts/eva/disko-fs.nix` 只供重装使用（`disko.enableConfig = false`），与 eva 的磁盘一致：by-id 路径、分区标签 ESP/primary、ESP 大小和子卷都相同                                                                                                                                                                                                                                                                                                                                    |
| ai 主机的 swap（磁盘 swapfile + zswap，不用 zram）                                                    | eva 使用 `@swap` 上已有的 64 GiB swapfile；muon 的 swapfile 未核实，仍用 zram                                                                                                                                                                                                                                                                                                                                                                                                       |
| ai 主机的 NVMe APST 参数                                                                              | 不迁移：上游 `WORKAROUNDS.md` 的 WA-008 只针对它自己那块硬盘                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ai 主机的 networkd 与 resolvectl DNS 接管                                                             | 不迁移：eva 只用 NetworkManager，没有 systemd-resolved；mihomo 的 TUN 自己劫持 DNS                                                                                                                                                                                                                                                                                                                                                                                                  |
| ai 主机的 smartd、CanoKey、WiVRn                                                                      | 迁到 eva；WiVRn 不自动启动（`just vr`）                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ai 主机的静态 binfmt 模拟器（e3a33fdf）                                                               | 采用：eva 和 muon 设置 `boot.binfmt.preferStaticEmulators`，podman/docker 容器和 chroot 中也能运行 aarch64、riscv64 程序。上游 2025-09 就有这项，此前一直没有迁到 eva；eva 的合并搬过来后，恢复 `hardware-configuration.nix` 时又被去掉                                                                                                                                                                                                                                             |
| fcitx5-vinput 本地语音输入（a695a3ce、#381、#384）                                                    | 采用：eva 和 muon 启用（`modules.desktop.vinput.enable`），按住右 Alt 说话，右 Ctrl 打开命令面板。持久化 `~/.config/vinput`，模型在已持久化的 `~/.local/share` 中；首次使用前运行一次 `vinput model add/use`（见 `home/linux/gui/base/vinput/README.md`）                                                                                                                                                                                                                           |
| 删除 omp 和 kimi-code CLI（349fe7f5、bf193e40）                                                       | omp 跟随删除：它是 pi 的超集，两者重复。kimi-code 按用户决定保留（仍在使用），`.kimi`、`.kimi-code` 的持久化随之保留                                                                                                                                                                                                                                                                                                                                                                |
| 删除 ctx7 的旧目录 `~/.context7`（0041afc2）                                                          | 采用：eva 上这个目录是空的，muon 未核实（见“待处理”）；ctx7 的登录写入已持久化的 `~/.config/context7`                                                                                                                                                                                                                                                                                                                                                                               |
| 持久化 pi 的 `~/.pi`                                                                                  | 补上：上游 ai 引入 pi 时（23258a06）就持久化了它，九月同步时漏掉                                                                                                                                                                                                                                                                                                                                                                                                                    |
| ai 主机针对 tmpfs 根的状态修复（#348、d9208f49）                                                      | 采用：持久化 `/var/lib/cups`、`/var/lib/logrotate`（logrotate 的状态写在其中）、`/var/lib/upower` 和 `/var/tmp`（`nosuid,nodev`，开机清空），开机清空 coredump；另按上游持久化 `.config/go-musicfox` 和 `.config/MangoHud`（后者来自 #393），`~/.android` 改为 0700。muon 导入 eva 的 preservation，同样生效。不采用 journald 的上限：`SystemMaxUse=10G` 高于 eva 默认的 4G，`RuntimeMaxUse=256M` 只限制开机早期 `/run` 中的日志。eva 和 muon 不运行 btrbk                          |
| tmpfs 根、`/tmp` 和 `/snapshots` 的挂载选项（#348）                                                   | 采用：加 `nosuid,nodev`，`/tmp` 另加 `noatime`。只改 eva 的 `hardware-configuration.nix` 和只供重装的 `disko-fs.nix`，muon 不变。setuid 程序在 `/run/wrappers`，`/nix`、`/dev`、`/run` 和 preservation 的绑定挂载都是单独的挂载点，不受影响                                                                                                                                                                                                                                         |
| 内核加固（#365，`hardening/kernel-hardening.nix`）                                                    | 采用。eva 上实际变化的只有 `fs.protected_fifos`/`fs.protected_regular`（1→2）、`kernel.kptr_restrict`（1→2）和 `net.core.bpf_jit_harden`（0→1）；`ptrace_scope=1`、`dmesg_restrict=1` 等原本就是内核默认值                                                                                                                                                                                                                                                                          |
| 用户不再属于 libvirtd 等等价于 root 的组（#335）                                                      | 采用；eva 没有启用 libvirtd，这个组成员关系原本就不起作用                                                                                                                                                                                                                                                                                                                                                                                                                           |
| 入站默认拒绝，只信任上游的局域网 `192.168.5.0/24`（#325）                                             | 用户决定（2026-10-14）：eva 只对自己的局域网 `192.168.1.0/24` 放行 SSH、Sunshine 和 mDNS（`hosts/eva/default.nix`），其余局域网入站仍然拒绝；muon 见“待处理”                                                                                                                                                                                                                                                                                                                        |
| AppArmor（#266）                                                                                      | 用户决定保留：只以 complain 模式加载 sudo 的规则                                                                                                                                                                                                                                                                                                                                                                                                                                    |
| 每天清理 30 天前放入回收站的文件（#265）                                                              | 用户决定 eva 和 muon 关闭：家目录的回收站在持久化的 `~/.local/share` 中，清理会删掉真实文件                                                                                                                                                                                                                                                                                                                                                                                         |
| 每周清理用户的 podman（6a026ecf）                                                                     | 用户决定 eva 关闭，保留已停止的容器；muon 用 Docker，本来就关闭；root 的清理保留                                                                                                                                                                                                                                                                                                                                                                                                    |
| 用户退出 docker、podman 组（13436c0c）                                                                | 用户确认接受：只是不能访问 root 的 podman socket，用户态容器不受影响                                                                                                                                                                                                                                                                                                                                                                                                                |
| 9 月合并删掉的工具（OBS 插件、blueman、nm-applet、virtctl、modelscope、ltrace、iftop、alsa-utils 等） | 用户事后确认接受（2026-10-14）；shell 历史中没有使用记录                                                                                                                                                                                                                                                                                                                                                                                                                            |
| 去掉 virtualisation 模块（VFIO、QEMU，#332）                                                          | 采用；eva 没有用到 VFIO。Flatpak 由本地的 `modules/nixos/desktop/misc.nix` 保留                                                                                                                                                                                                                                                                                                                                                                                                     |
| agents 模块（#367）                                                                                   | 采用，但 rules 和 skills 默认关闭（`modules.agents.globalRules.enable`、`modules.agents.skills.enable`）：这些主机的 `~/.codex/AGENTS.md` 和 `~/.agents/skills` 由用户和 oh-my-codex 管理                                                                                                                                                                                                                                                                                           |
| 编辑器环境变量统一在 `modules/base/packages.nix`（`SUDO_EDITOR = hx`）                                | 采用                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| Neovim 从 nixvim 改为 `programs.neovim`（#336）                                                       | 采用；去掉 nixvim input 和 astra 的 26.05 包集设置。Catppuccin 只为 Neovim 开启（`theme.nix` 中 `autoEnable = false`，Zed 不受影响）                                                                                                                                                                                                                                                                                                                                                |
| opencode 改为 opencode2（01ed0aa5）                                                                   | 采用                                                                                                                                                                                                                                                                                                                                                                                                                                                                                |
| #332 删除"用不到"的工具                                                                               | 本地没改过的行跟随上游删除。本地改过的列表（`home/base/core/core.nix`、`home/base/tui/dev-tools.nix`、`home/base/tui/editors/packages.nix`、`home/linux/gui/base/creative.nix`、`modules/base/packages.nix`）在冲突中保留了本地条目，hydra-check、nix-init、cowsay、tokei、inkscape、procs、wget 等因此仍在。按用户决定保留容器/K8s/云工具：lazydocker、kubebuilder、clusterctl、kubectl-tree、go-containerregistry、ko、eksctl、ssm-session-manager-plugin、google-cloud-sql-proxy |
| #332 删除的 mongosh、gitleaks                                                                         | 用户事后确认跟随上游删除（2026-10-13）。合并时按上一行处理，当时没有单独询问                                                                                                                                                                                                                                                                                                                                                                                                        |
| 删除 OpenLDAP 测试覆盖（e8f80990）                                                                    | 采用：删除 `modules/base/overlays.nix` 和独立 HM 中的覆盖，以及随之多余的 `modules.darwin.upstreamOpenldap` 选项                                                                                                                                                                                                                                                                                                                                                                    |
| 删除 foot 和 Alacritty，终端只留 ghostty 和 kitty（#349）                                             | 采用；eva 登录时自启 ghostty 和 kitty                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Qt 平台主题改为 `xdgdesktopportal`（9cc5d924）                                                        | 采用：Qt 应用跟随系统深浅色；字体仍是 Qt 内置的 Sans Serif 9                                                                                                                                                                                                                                                                                                                                                                                                                        |
| plocate 全盘文件名搜索（#333、#356）                                                                  | 采用；eva 和 muon 不持久化 `/var/cache`，数据库在内存里，重启后要等下一次定时扫描                                                                                                                                                                                                                                                                                                                                                                                                   |
| 删除 PipeWire 的 JACK 支持（#357）                                                                    | 采用；eva 上没有只能用 JACK 的程序                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| 删除 herdr（#374）                                                                                    | 采用；eva preservation 中的 herdr 目录一并删除                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| WeChat 改用 nixpkgs-master 的包（a1ec97d3，WA-007）                                                   | 采用。nixpkgs 从 web.archive.org 下载 AppImage，eva 直连时连不上，构建前要打开代理                                                                                                                                                                                                                                                                                                                                                                                                  |
| 用 umu 取代 Lutris 和 ProtonPlus（#411）                                                              | 采用：删除 Lutris、ProtonPlus，以及只为 Lutris 保留的 `pkgs-x64` 包集（上游 13fe3245）和 Lutris 的持久化条目；eva 上的数据已按用户要求删除（2026-10-13）                                                                                                                                                                                                                                                                                                                            |
| Steam 不再提供 gamescope 会话（#393）                                                                 | 采用：GDM 中不再有 Steam 会话；Proton 由 `extraCompatPackages` 声明，gamescope 带 `capSysNice`，可在游戏启动参数中使用                                                                                                                                                                                                                                                                                                                                                              |
| 去掉 TuneD，CPU 调频交给内核的 P-state 驱动（#461）                                                   | 用户决定跟随（2026-10-26）。eva 原来运行 TuneD 的 balanced；配置中的 `performance` 默认值从未生效，上游 #458 查明原因是 tuned-ppd 先恢复保存的 profile。现在 GNOME 启用 power-profiles-daemon，由它提供电源模式菜单；`hosts/eva/preservation.nix` 持久化 `/var/lib/power-profiles-daemon`（muon 共用）。`/persistent` 中 2025-06 的 state.ini 选的是 performance，切换后沿用                                                                                                        |
| 去掉 TuneD 的附带变化：TuneD 模块会开启 setuid 的 pkexec                                              | 用户决定跟随（2026-10-26）。eva 和 muon-niri 仍由 GNOME 开启它；muon 的默认配置没有图形会话，不再有 pkexec，需要 root 时用 sudo。polkit 本身仍开启（NetworkManager、udisks2 需要它）                                                                                                                                                                                                                                                                                                |
| vinput 的配置放进仓库，daemon 读取 `~/.secrets/nushell-secrets.env`（#445）                           | 用户决定不采用，见“有意保留的差异”                                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| exporter 必须绑定 vars 中的局域网地址（新测试 `exportersBoundToLan`）                                 | 用户决定在 eva、muon 上关闭 node 和 smartctl exporter：这两台的地址由 NetworkManager 分配，与 vars 中的不同；防火墙只对 youko 放行这些端口，没有主机抓取它们                                                                                                                                                                                                                                                                                                                        |
| ai 的内存回收参数（swappiness 20、watermark_scale_factor 100、watermark_boost_factor 0）              | 用户决定迁到 eva，取代原来的 watermark_scale_factor 50。eva 与 ai 一样用 swapfile 加 zswap；muon 用 zram，不变                                                                                                                                                                                                                                                                                                                                                                      |
| dsh 改用 nur-ryan4yin 的构建和只用 Nushell 的插件（#473、#475、#476）                                 | 用户决定保留 llm-agents 的普通 dsh，删除用不到的 `dsh-nu` input                                                                                                                                                                                                                                                                                                                                                                                                                     |
| 删除 conda（789b2307）                                                                                | 用户决定跟随。eva、muon 去掉 conda 和 `.conda` 的持久化（eva 的 `~/.conda` 是空的）；astra 没有装 miniforge，它的 conda 初始化代码随之删除；fern、frieren 的 miniforge cask 跟随删除                                                                                                                                                                                                                                                                                                |
| EasyEffects 的响度预设不处理 mpv、Zoom 和腾讯会议的声音（11569839）                                   | 用户决定跟随；eva 另持久化 `~/.config/easyeffects`（设置数据库），预设所在的 `~/.local/share` 本来就已持久化                                                                                                                                                                                                                                                                                                                                                                        |
| SSH 的局域网设置（#446、#463，WA-035）                                                                | 用户决定跟随：`192.168.*` 和 vars 中的主机名连接超时 1 秒、重试 3 次、连接复用 30 分钟；`192.168.*` 不再固定使用 `/etc/agenix/ssh-key-romantic`。这些设置仍由 `modules.ssh.personalConfig` 开关控制                                                                                                                                                                                                                                                                                 |
| yazi 的 4 个插件和按键（#469）                                                                        | 用户决定跟随；`-` 从创建符号链接改为缩小预览                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| ai 的 DDC/CI（ddcutil、`hardware.i2c`）和 OpenRGB                                                     | 用户决定迁到 eva。OpenRGB 管理主板的 RGB Fusion（ITE 048d:5711），持久化 `/var/lib/OpenRGB` 和 `~/.config/OpenRGB`；muon 不变                                                                                                                                                                                                                                                                                                                                                       |
| ai 的主板传感器驱动 nct6683                                                                           | 不迁移：eva 的技嘉主板需要树外的 it87 驱动                                                                                                                                                                                                                                                                                                                                                                                                                                          |
| niri 的 NVIDIA 显存池上限（WA-039）                                                                   | 迁到 eva 和 muon，只在 `-niri` 变体中生效（`hosts/eva/nvidia-niri.nix`）                                                                                                                                                                                                                                                                                                                                                                                                            |
| 删除 VS Code（add8ad97）                                                                              | 用户决定 eva 和 muon 保留（2026-10-30）。上游没有写理由，它 2026-08 曾为 build123d 加回 VS Code。eva 上 `~/.vscode` 和 `~/.config/Code` 共 6.9 GB、174 个扩展，最近一次使用在 2026-08。fern/frieren 的 cask 跟随删除；astra 的 VS Code 是手动安装的，不受影响                                                                                                                                                                                                                       |
| helm 改用当前 nixpkgs（WA-002，e8e9691f）                                                             | 用户决定跟随（2026-10-30）：helm 从 3.17.3 升到 4.3.1（大版本变化，与用 Nix 之前 astra 上 Homebrew 的 4.3 一致），删除 `nixpkgs-2505` input                                                                                                                                                                                                                                                                                                                                         |
| 重新加入 gitleaks（38d1d85e）                                                                         | 跟随：2026-10-13 用户确认跟随上游删除它，上游现在又加回                                                                                                                                                                                                                                                                                                                                                                                                                             |
| Nushell 开启 `loadSessionVariables`（e8e9691f）                                                       | 跟随：Home Manager 26.11 的默认值，各主机的 HM 多出 `~/.config/nushell/env.nu`                                                                                                                                                                                                                                                                                                                                                                                                      |
| ai 的输出按需开启 VRR（def7d8f7）                                                                     | 不迁移：eva 的桌面是 GNOME，niri 只是备用；是否开启 VRR 取决于 eva 的显示器                                                                                                                                                                                                                                                                                                                                                                                                         |

### 有意保留的差异

| 路径                                                                                                                                                    | 类别 | 原因                                                                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------------------------------------------------- | ---- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `home/linux/gui/base/fcitx5`、`pkgs/fcitx5`                                                                                                             | b    | 本地的 fcitx5 与 Rime 包；不采用上游共享的 `home/base/gui/rime`（5e5707dd）                                                                                                              |
| `home/darwin/rime-squirrel.nix`                                                                                                                         | c    | 上游 5e5707dd 删除了它，改用共享的 Rime 模块；本地保留自己的方案                                                                                                                         |
| `home/base/core/theme.nix`                                                                                                                              | b    | Catppuccin 只用于 Neovim（`autoEnable = false`），其余程序保持各自的主题                                                                                                                 |
| `modules/base/nix.nix`                                                                                                                                  | b    | 用户决定保留 `trusted-users`；上游 #335 出于安全考虑删除了它                                                                                                                             |
| `home/base/tui/agents/{packages.nix,README.md,dsh.md}`、`flake.nix`                                                                                     | b    | 本地的 agent CLI 列表；dsh 用 llm-agents 的普通构建，不用上游的 nur-ryan4yin 构建及其 Nushell 插件，因此没有 `dsh-nu` input；Codex 用 pnpm 安装                                          |
| `home/linux/gui/base/vinput`                                                                                                                            | b    | 配置由用户自己管理，不采用上游 #445 的 `config.json`（Ryan 局域网的 ASR 服务和 DeepSeek 场景）、`aqua-provider.py` 和必需的 `EnvironmentFile`；eva 和 muon 继续持久化 `~/.config/vinput` |
| `hosts/{eva,muon}/default.nix` 中的 exporter                                                                                                            | b    | 关闭 node 和 smartctl exporter，原因见上表                                                                                                                                               |
| `outputs/x86_64-linux/tests/{cpu-power,microvm-guest-parity}`、`outputs/aarch64-linux/tests/cpu-power`                                                  | b    | 主机列表按本地主机改写，原因见上文“2026-10-26：合入 b334336c”                                                                                                                            |
| `vars/default.nix` 的 `permittedInsecurePackages`，以及读取它的 `modules/nixos/base/nix.nix`、`lib/macosSystem.nix`、`lib/homeManagerConfiguration.nix` | b    | 放行 Zotero 所用的、已停止支持的 Firefox ESR 140，见上文“2026-10-26：合入 b334336c”                                                                                                      |
| `home/base/tui/container.nix`、`home/base/tui/cloud`                                                                                                    | b    | 按用户决定保留上游 #332 删除或注释掉的容器、K8s 与云工具                                                                                                                                 |
| `home/linux/gui/base/{vscode.nix,README.md,xdg/mime.nix}`、`README.md`、`hosts/eva/preservation.nix` 中的 VS Code                                       | b    | 用户决定保留 VS Code，上游 add8ad97 删除了它                                                                                                                                             |
| `modules/base/security.nix`、`WORKAROUNDS.md` 的 WA-040                                                                                                 | c    | 不设根证书黑名单：锁定的 nixpkgs 的 `ca.nix` 和 nix-darwin bb0b90db 的 pki 模块都已自己加入 "Comodo AAA Services root"；上游 e8e9691f 认为 nix-darwin 只透传这个列表，与锁定的版本不符   |
| `flake.nix` 的 `rust-overlay` input                                                                                                                     | b    | `pkgs/warp-terminal` 把它传给 Warp 上游的 flake；上游删除它，是因为 lanzaboote 不再需要跟随它                                                                                            |
| `secrets/README.md`                                                                                                                                     | b    | 私有 secrets 仓库仍用 `secrets.nix`；上游 01d2e764 把它的私有仓库改为 `agenix-rules.nix`，并去掉了规则键的 `./` 前缀                                                                     |
| `home/base/tui/tuios/config.toml`                                                                                                                       | b    | leader 键为 Ctrl+Z                                                                                                                                                                       |
| `justfile` 的 `clean`                                                                                                                                   | b    | 保留 `--older-than 7d`，不像上游 59f194f0 那样清除全部历史 generation                                                                                                                    |
| `home/darwin/shell.nix`                                                                                                                                 | c    | 上游 6218bb22 把 Homebrew 放到 PATH 最前；本地追加在后，使 Nix 包优先于 Homebrew，astra 的 PATH 顺序依赖这一点                                                                           |
| `home/darwin/ssh.nix`                                                                                                                                   | c    | 上游 b44d2770 改用系统级 SSH 配置并删除此文件；独立 HM 输出 `vitalyr@aarch64-darwin` 不经过 nix-darwin，主机别名只能来自这里                                                             |
| `home/darwin/default.nix`                                                                                                                               | b    | Home Manager 26.05 在 Darwin 上默认 `programs.man.package = null`，因此关闭 man 缓存                                                                                                     |
| `home/darwin/proxy`                                                                                                                                     | b    | 加了启用开关；proxychains 的链接指向 `repoRoot` 下的仓库，而不是上游的 `~/nix-config`                                                                                                    |
| `home/darwin/karabiner`、`home/darwin/input-source-pro`、`home/darwin/README.md`                                                                        | b    | astra 的键位与输入法                                                                                                                                                                     |
| `modules/darwin/{nix-daemon,system-paths}.nix`                                                                                                          | b    | 所有 Darwin 主机共用的本地模块                                                                                                                                                           |
| `modules/darwin/README.md`                                                                                                                              | b    | 文案                                                                                                                                                                                     |
| `secrets/darwin.nix`、`secrets/nixos.nix`                                                                                                               | b    | 私有 secrets 仓库的布局与上游不同（1a10e652 等）；secret 文件不存在时跳过，astra、eva 和 muon 的 secrets 合并前后相同                                                                    |
| `AGENTS.md`                                                                                                                                             | b    | 本地的 agent 指南（oh-my-codex 与本仓库的规则），与上游的 `AGENTS.md` 无关；每次合并都保留本地版本                                                                                       |
| 上游 ai 主机的 eval 测试（`idols-ai-gpu`、`idols-ai-voice-input`、`idols-ai-net`）                                                                      | b    | 本地不构建 ai，eva 是它的继任者：前两个已改写为 `eva-vr`、`eva-input-method`，`idols-ai-net` 只适用于 ai 的 networkd                                                                     |
| `home/hosts/darwin`、`hosts/darwin-astra`、`outputs/aarch64-darwin`                                                                                     | b    | astra 主机、fern 的 Emacs、独立 HM 输出与 eval 测试                                                                                                                                      |

### 其他修正

- 按用户决定删除未导入的 `hosts/{eva,muon}/mihomo.nix`（2025 年的 mihomo 开关）和
  `hosts/muon/preservation.nix`（已被 eva 的 preservation 取代）。
- muon 的 `disabledModules` 原来写成字符串，按 nixpkgs 的模块目录解析，从未禁用共享的
  `modules/nixos/base/user-group.nix`。改为路径后，muon 的用户和组只来自
  `hosts/muon/users.nix`：fish 照旧开启，muon 用不到的 `fileshare`
  组随之去掉，root 的 SSH 公钥不再重复列出。
- 安装器 flake 只导入 `modules/base`
  中它能求值的文件（overlays 需要安装器没有的 input），shoukei 补上 `mylib` 和
  `myvars`。muon 的安装配置改用 `hosts/muon/users.nix`，与 muon 本身一致：`preservation-users.nix`
  保留的用户都有定义，主用户也用 muon 固定的 UID，首次部署完整配置后文件属主不变。shoukei 没有
  `my-asahi-firmware` input，`apple-silicon.nix`
  因此关闭 Asahi 支持（主 flake 中也是这样），这个目标能求值，但装不出可启动的 shoukei。

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

不要在 eva 和 muon 上开启
`modules.networking.mihomo.resolvedIntegration`（上游 b24f30c3）：它会启用 systemd-resolved 并让 NetworkManager 改用它，而这两台主机只用 NetworkManager 管理 DNS。

### 待处理

- muon 的防火墙：muon 的局域网是 10.7.220.x，不在 `lanCidr`
  中，而且它开着密码登录的 SSH。切换 muon 前先决定局域网能访问哪些服务（eva 的做法见上文 #325 一行）。
- 工作 alias：本地仍用
  `/etc/agenix/alias-for-work.nushell`（`secrets/nixos.nix`）。上游 0e124401 改为不经 agenix 的
  `~/.secrets/nushell-secrets.nu`，未采用；私有仓库目前没有这两个文件。
- fern/frieren 的 `codex-app` cask 已被 Homebrew 停用（替代品为 `chatgpt` cask），上游仍在使用。
- 切换到 mihomo（见上文），需要先准备 `sources.yaml`。
- Cataclysm DDA 和 Warzone 2100 暂用 nixpkgs
  26.05 的包（`home/base/gui/games.nix`）：unstable 改用 GCC
  16 后编译不了它们，缓存里也没有，2026-10-26 时仍是这样。unstable 能构建后改回。contour 已改回 unstable。
- 切换 muon 前：若它的 `/var/lib/cups/printers.conf`
  存在，先停掉 CUPS（`sudo systemctl stop cups.socket cups.service`），再把整个目录复制到持久卷：`sudo cp -a /var/lib/cups/. /persistent/var/lib/cups/`。各队列的 PPD（`ppd/`）和
  `classes.conf` 也在这个目录里，只复制 `printers.conf`
  的话，重启后队列没有 PPD，会变成 raw 队列；目录中指向 Nix
  store 的符号链接由 cups 的 preStart 重建。eva 的 `/var/lib/cups` 里没有打印机配置。
- 切换 muon 前：对每个用户检查
  `/persistent/home/<用户>/.context7/credentials.json`，存在就移到同一用户的
  `/persistent/home/<用户>/.config/context7/`（目录 0700，属主为该用户）。`~/.context7`
  不再持久化，ctx7 又不能跨绑定挂载自己移动旧的登录，不移的话登录会被遮住。eva 的 `~/.context7`
  是空的。
- Zotero 换到受支持的 ESR 后，删掉 `vars/default.nix` 中 `permittedInsecurePackages`
  的条目。在此之前，Zotero 所用的 Firefox ESR 140 不再有安全更新。
- 切换 muon 前：对每个用户检查
  `/persistent/home/<用户>/.conda`。b334336c 的合并删除了 conda，不再持久化
  `~/.conda`（eva 的是空的）；里面有 conda 环境的用户切换后在家目录中看不到它们。数据仍在
  `/persistent` 中；有人在用的话，切换前把它们移到别处，或者恢复这一项持久化。
- 私有 secrets 仓库的规则文件：agenix 0.18 已把 `RULES` 和自动查找 `secrets.nix`
  标为弃用，以后的版本会删除。私有仓库改名为 `agenix-rules.nix`、规则键去掉 `./`
  前缀之后，`secrets/README.md` 再改用上游的写法（上游 01d2e764）。
- dsh 升到 0.2.1-rc.5（57e96049）之后，web
  profile 的插件要重新固定到 rc.5，并在下次启动的错误输出中检查有没有 `disabling profile plugin`。

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

**eva 上求值卡在从 nix-community 下载 `-source`**：flake
input 的源码带 narHash，Nix 会先尝试从 substituters 下载。nix-community 的缓存从 eva 访问很慢时，求值就停在这一步（2026-10-30 的一个 217
MB 的 nixpkgs 源码就是这样）。先只用 cache.nixos.org 取回所有 input，缓存中没有的会直接从 GitHub 下载：

```bash
nix flake archive --option substituters https://cache.nixos.org
```

**从 cache.nixos.org 下载很慢**：构建时由 nix-daemon 下载，它不读取用户 shell 中的代理环境变量。可以先用
`nix build --dry-run` 列出要下载的路径，以用户身份用 `nix copy`
预先取回，再构建。签名由 cache.nixos.org 的密钥校验，换下载来源不影响结果：

```bash
# astra：经本机的 HTTP 代理（2026-10-30：直连约 110 KB/s，经代理约 1.5 MB/s）
https_proxy=http://127.0.0.1:<端口> nix copy --from https://cache.nixos.org <路径>...
# eva：上海交大的 cache.nixos.org 镜像（2026-10-30：直连约 250 KB/s，镜像约 2 MB/s）
nix copy --from https://mirror.sjtu.edu.cn/nix-channels/store <路径>...
```

已配置的 tuna、ustc 镜像只缓存部分路径，2026-10-30 时这些路径都返回 404。CUDA 等不在 cache.nixos.org 的包仍从 nix-community 或 NVIDIA 下载。

**在 astra 上求值 eva 失败**：eva 的配置用到 IFD（例如 codex-desktop-linux、Warp 的源码），需要 x86_64-linux 构建。改到 eva 上求值。

**eva 上构建 Go 包时下载依赖超时**：Go 包的依赖（`<包>-go-modules`
派生）从 proxy.golang.org 下载，eva 直连不通（`dial tcp ...:443: i/o timeout`）。打开 Clash
Verge 的 TUN 模式后重新构建；或者在沙箱外经 goproxy.cn 构建，再按哈希加入 store。依赖由 `go.sum`
校验，加入 store 时又按 vendorHash 校验，所以换代理不影响结果（2026-10 的 tuios
v0.10.1 就是这样构建的）：

```bash
drv=<失败的 go-modules 派生>; name=<派生的名字>; work=$(mktemp -d)
nix-shell "$drv" --pure --run "export HOME=$work/home GOENV=off GOPROXY=https://goproxy.cn,direct out=$work/$name TMPDIR=$work/tmp; mkdir -p \$HOME \$TMPDIR; cd $work; genericBuild"
nix-store --add-fixed --recursive sha256 "$work/$name"   # 应输出该派生原本的输出路径
```

**eva 构建 Firefox ESR 时被 OOM 杀掉**：eva 和 muon 设置了
`nixpkgs.config.cudaSupport = true`，它们的 Firefox
ESR 因此与缓存中的不同，只能本地编译；链接 libxul 约需 37
GB 内存，与 CUDA 包同时构建时会耗尽 eva 的 60 GB。先用 `--max-jobs 1`
单独构建它，再构建整个系统。目前只有 Zotero 用到 Firefox
ESR，而 2026-10 起 nixpkgs 的 Zotero 用二进制的 Firefox ESR 140，所以现在不必编译。

**拉取合并后 astra 求值失败**：先运行 `just merge-audit <合并提交>`（合并后又有修正提交时，用上文的
`--ours`/`--theirs` 形式），检查合并有没有整个文件取一侧；再看 `just upstream-darwin`
列出的提交是否删除了 astra 使用的选项。
