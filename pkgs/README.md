# self-host pkgs

## 如何定义新的包

支持两种格式: - /pkgs/package-name/package.nix 最终会得到 pkgs.package-name - /pkgs/<folder>/{a.nix,
b.nix} 最终会得到 pkgs.a pkgs.b

定义完后，git add file 即可。

## 如何通过 nvfetcher 修改软件

例如，emacs，在 `nvfetcher.toml` 中定义

```toml
[source-emacs-master-igc]
src.git = "https://github.com/emacs-mirror/emacs.git"
src.branch = "scratch/igc"
fetch.github = "emacs-mirror/emacs"
```

然后在 `emacs/emacs-master-igc-pgtk.nix` 中，传入的函数加上 `source-emacs-master-igc` 参数，并替换掉
原有的src

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
