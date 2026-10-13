{
  # Nix records which Homebrew packages astra needs; Homebrew installs and updates
  # them. docs/astra-macos-host.md explains the policy behind each setting.
  homebrew = {
    enable = true;

    onActivation = {
      # Activation stops before changing anything while a package that is not listed
      # here is installed, so every Homebrew package stays declared. "uninstall" and
      # "zap" would remove unlisted packages instead (zap also deletes cask data such
      # as ~/Library/Application Support/Zotero).
      cleanup = "check";
      # Versions change only on request: the casks other than godot update
      # themselves; godot and formulae are upgraded with `brew upgrade`.
      autoUpdate = false;
      upgrade = false;
      # Activation runs `brew bundle` through sudo, which drops the user's
      # environment. Home Manager exports the same variables for interactive use.
      extraEnv = {
        HOMEBREW_API_DOMAIN = "https://mirrors.ustc.edu.cn/homebrew-bottles/api";
        HOMEBREW_BOTTLE_DOMAIN = "https://mirrors.ustc.edu.cn/homebrew-bottles";
        HOMEBREW_BREW_GIT_REMOTE = "https://mirrors.ustc.edu.cn/brew.git";
        HOMEBREW_CORE_GIT_REMOTE = "https://mirrors.ustc.edu.cn/homebrew-core.git";
      };
    };

    # `brew bundle check` and `brew bundle cleanup` read the generated Brewfile.
    global.brewfile = true;

    # Apps that update themselves or need the vendor's installation in /Applications,
    # plus Godot's official release (pkgs.godot builds Godot's development branch).
    casks = [
      "godot"
      "input-source-pro"
      "karabiner-elements"
      "microsoft-edge"
      "obsidian"
      "warp"
      "wechatwebdevtools"
      "zotero"
    ];

    # Only tools that Nix does not provide here: Nix precedes Homebrew on PATH.
    brews = [
      "cloudflared"
      "colima"
      "docker"
      "docker-buildx"
      "docker-compose"
      # Warp sessions start this Fish (modules.desktop.warp in
      # home/hosts/darwin/darwin-astra.nix); `fish` on PATH is from Nix.
      "fish"
      # OpenMP runtime that local builds link from /opt/homebrew/opt/libomp.
      "libomp"
      "macmon"
      "modal"
      "openconnect"
      # Server run by `brew services`; its data is in /opt/homebrew/var/postgresql@17.
      "postgresql@17"
      "samply"
      # Nix now provides sshpass (modules/base/packages.nix). Uninstall the brew before the next
      # activation: cleanup = "check" stops while an undeclared formula is installed.
      # "sshpass"
      "tea"
    ];
  };
}
