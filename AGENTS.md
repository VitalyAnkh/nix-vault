# AGENTS.md（给后续自动化/协作修改用）

本仓库是 NixOS（以及部分 nix-darwin）主机配置的 flake。常用主机是 `eva` 与 `muon`。

`muon` 的关键特性：`/` 使用 `tmpfs`（stateless root），状态通过 `preservation` 挂载到
`/persistent`，并且在 **initrd 阶段**就会执行 NixOS activation。很多“重启后偶发”的问题，本质是
**启动时序 + 持久化边界**导致的。

## 总体规范

- 先读清 `hosts/<host>/default.nix` 的 `imports`，确认“问题配置到底来自哪个模块”（例如 `muon` 会复用
  `hosts/eva/preservation.nix`）。
- 修复优先找根因，避免只靠 `chown`/`mkdir`
  等表面补丁；但当需要迁移既有数据时，可以用一次性的 systemd 迁移服务收敛风险。
- 不改写 git 历史；不要擅自 `git reset` 或清 staged 变更；避免 `git add -A` 把无关文件一起 stage。

## stateless + preservation 的注意事项（最容易踩坑）

### 0) 大量 bind mounts 会拖垮 systemd 的 mount namespace（导致 logind/polkit 等随机超时）

在 `muon` 这类 root=tmpfs + preservation 机器上，系统里可能会出现 **上千条** bind
mount（例如把很多 home 子目录分别挂载出来）。

一些 systemd 服务默认启用 hardening（例如 `ProtectSystem=strict` / `ProtectHome=yes` /
`PrivateTmp=yes` / `PrivateDevices=yes`），会要求 systemd 为该服务创建 **私有 mount
namespace**。当 mount 数量过大时，namespace 初始化/重挂载可能超过默认
`TimeoutStartSec=90s`，表现为：

- `systemd-logind.service: start operation timed out`（进而出现
  `Unable to list users with logind`，导致 `nixos-rebuild switch` 失败、GNOME 起不来等连锁反应）
- `polkit.service`、`avahi-daemon.service`、`systemd-hostnamed.service` 等类似超时

**优先修复路径：**

- 从根上减 mount 数：尽量用更高层级目录持久化，避免为大量细碎路径生成成千上万 bind mount。
- 或者对关键服务放宽 hardening（仅限需要）：在 `hosts/muon/default.nix` 用
  `systemd.services.<name>.serviceConfig` 关闭触发 mount namespace 的项（例如
  `ProtectSystem/ProtectHome/PrivateTmp/PrivateDevices`）。
- 验证时不要只看 `build`：要从 toplevel 的 `etc/systemd/system/*`
  或 drop-in 里确认这些 override 真实落入生成物。

### 1) UID/GID “漂移”会表现为“随机用户拥有文件”

- Linux 文件 owner 的真相是“数字 UID/GID”，用户名只是解析结果。
- 如果启动早期生成/使用的 UID 映射与后续实际使用的不一致，就会出现：
  - 文件的数字 UID 没变，但 `ls -l` 显示的用户名变成 `sw`/其它用户（看起来像“被随机用户拥有”）。
- 典型原因是在 initrd/activation 阶段 `/var/lib/nixos` 还没从持久化卷挂上来，导致生成了一套临时
  `uid-map`/`gid-map`，切根后又被持久化的映射覆盖。

**排查要点：**

- `stat -c '%u:%g %U:%G %n' <path>`：先看数字 UID/GID。
- `getent passwd <name>`：核对当前用户名→UID。
- `jq -r 'to_entries|sort_by(.value)|.[]|\"\\(.value)\\t\\(.key)\"' /var/lib/nixos/uid-map`：核对映射（需要
  `jq`）。
- 若 `uid-map` 与 `getent passwd` 不一致，优先怀疑 initrd 挂载时序或 UID 分配不固定。

### 2) `/var/lib/nixos` 需要在 initrd 可用

在 `muon` 这类“initrd 跑 activation + root=tmpfs”的机器上：

- 把 `/var/lib/nixos` 纳入 preservation 持久化并设置
  `inInitrd = true`，保证 initrd 阶段就能读到稳定的 `uid-map/gid-map`。

### 3) 多用户机器务必显式固定 `uid`

- 不要依赖“声明顺序/历史生成的 uid-map”来给普通用户分配 UID。
- 对 `users.users.<name>.uid`
  做显式固定，可从根上消除“新增/删除用户后 UID 重新分配”引发的 ownership 解析混乱。

### 4) 修改既有用户 UID 必须做数据迁移

如果必须把 `vitalyr` 改到 `uid=1000` 这类变更：

- 必须同步处理 `/persistent/home/<user>`（以及其它持久化路径）内旧 UID 文件的
  `chown`，否则重启后“看起来还是别人的文件”。
- 推荐做法：新增一个 **oneshot** systemd 服务：
  - `After=preservation.target`，确保持久化卷已挂载。
  - 如果启用了 `home-manager-<user>.service`：迁移服务需要
    `Before=home-manager-<user>.service`，避免首次重启时 Home Manager 先启动导致失败。
  - `Before=systemd-user-sessions.service display-manager.service`，尽量在用户登录/图形界面前完成。
  - 通过 `stat -c %u` 检测“旧 ownership 模式”再执行 `chown -R`，保证幂等（迁移完成后变成 no-op）。

## /home 目录的创建与权限

- preservation 往往只会 bind-mount 用户家目录下的若干子目录（例如 `.config`、`.local/state` 等）。
- 在 `root=tmpfs` 场景下，`/home/<user>` 可能会被不同组件“先创建”，导致 owner/mode 受默认行为影响。
- 建议用 `systemd.tmpfiles` 显式声明
  `/home/<user>`（以及需要的父目录）权限，避免时序导致的错误 owner/mode。

## 验证流程（不要只停在 build 成功）

### 构建期验证（必须）

- `nixos-rebuild build --flake .#<host>`

### 生成物核对（强烈建议）

从 build 产物（toplevel）中核对关键点是否真的进入配置：

- `users-groups.json`：确认目标用户的 `uid`/`home` 正确。
- initrd mount units：确认关键持久化路径（尤其
  `/var/lib/nixos`）在 initrd 阶段有对应挂载单元且排序正确。
- `etc/tmpfiles.d/preservation.conf` / 相关 tmpfiles：确认 `/home/<user>` 或关键目录的规则存在。
- systemd unit：确认迁移服务 unit 被生成且依赖/排序符合预期。

### 运行态验证（最终结论以此为准）

需要在目标机器执行：

- `sudo nixos-rebuild switch --flake .#<host>`
- `sudo reboot`
- 重启后检查：
  - `getent passwd vitalyr`
  - `stat -c '%u:%g %U:%G %a %n' /home/vitalyr /persistent/home/vitalyr`
  - 如仍异常，优先对比数字 UID 与 `/var/lib/nixos/uid-map`、`getent passwd` 的一致性。

## 调试习惯

- 发生“偶现”问题：用
  `journalctl -b | rg -i 'tmpfiles|preservation|activation|update-users|uid-map|gid-map'`
  先看启动顺序与报错。
- Home
  Manager 启动失败：优先看它在当次 boot 实际以哪个 UID 跑（`journalctl -b -1 -u home-manager-<user>.service -o verbose | rg _UID`），再对照
  `stat -c %u` 的数字 ownership。
- Home Manager `reloadSystemd` 阶段会用 `sd-switch` 启动/重启用户服务：如果某个 user
  unit 在当前桌面会话下必然失败（例如 GNOME 下的 `waybar`、重复的 `polkit-gnome`、没有 hypr
  socket 的 `hypridle`），会导致整次 activation 直接退出；可用 systemd 条件（例如
  `ConditionPathIsDirectory=%t/hypr`）把这些服务限定到 Hyprland 会话。
- 搜索代码优先用 `rg`；理解 module 合并顺序，尽量减少跨主机的意外影响（尤其修改 `hosts/eva/*`
  这类被复用模块时）。
