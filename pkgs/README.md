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
src.git = "https://github.com/emacs-mirror/emacs.git"
src.branch = "feature/igc3"
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

在当前目录下执行 nvfetcher 命令，然后 git commit 出现的 generated.nix
