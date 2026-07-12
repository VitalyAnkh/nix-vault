{
  preservation,
  pkgs,
  myvars,
  ...
}:
let
  inherit (myvars) username;
in
{
  imports = [
    preservation.nixosModules.default
  ];

  preservation.enable = true;
  # preservation requires initrd using systemd.
  boot.initrd.systemd.enable = true;

  environment.systemPackages = [
    # `sudo ncdu -x /`
    pkgs.ncdu
  ];

  # There are two ways to clear the root filesystem on every boot:
  ##  1. use tmpfs for /
  ##  2. (btrfs/zfs only)take a blank snapshot of the root filesystem and revert to it on every boot via:
  ##     boot.initrd.postDeviceCommands = ''
  ##       mkdir -p /run/mymount
  ##       mount -o subvol=/ /dev/disk/by-uuid/UUID /run/mymount
  ##       btrfs subvolume delete /run/mymount
  ##       btrfs subvolume snapshot / /run/mymount
  ##     '';
  #
  #  See also https://grahamc.com/blog/erase-your-darlings/

  # NOTE: preservation only mounts the directory/file list below to /persistent
  # If the directory/file already exists in the root filesystem you should
  # move those files/directories to /persistent first!
  preservation.preserveAt."/persistent" = {
    directories = [
      "/etc/NetworkManager/system-connections"
      "/etc/ssh"
      "/etc/nix/inputs"
      "/etc/secureboot" # lanzaboote - secure boot
      # my secrets
      "/etc/agenix/"

      "/var/log"
      # preserve davfs2 cache to keep WebDAV mounts from shifting load into RAM
      "/var/cache/davfs2"

      # VR_TODO: for proxy apps run with sudo
      "/root/.local"
      "/root/.config"

      # system-core
      {
        directory = "/var/lib/nixos";
        inInitrd = true;
      }
      "/var/lib/systemd"
      {
        directory = "/var/lib/private";
        mode = "0700";
      }

      # containers
      "/var/lib/docker"
      "/var/lib/cni"
      "/var/lib/containers"

      # other data
      "/var/lib/flatpak"

      # virtualisation
      "/var/lib/libvirt"
      "/var/lib/lxc"
      "/var/lib/lxd"
      "/var/lib/qemu"
      # "/var/lib/waydroid"

      # network
      "/var/lib/tailscale"
      "/var/lib/netbird-homelab" # netbird's homelab client
      "/etc/netbird-homelab"
      "/var/lib/bluetooth"
      "/var/lib/NetworkManager"
      "/var/lib/iwd"
    ];
    files = [
      # auto-generated machine ID
      {
        file = "/etc/machine-id";
        inInitrd = true;
      }
    ];

    # the following directories will be passed to /persistent/home/$USER
    users.${username} = {
      commonMountOptions = [
        "x-gvfs-hide"
      ];
      directories = [
        # ======================================
        # XDG Directories
        # ======================================

        "Desktop"
        "Downloads"
        "Music"
        "Pictures"
        "Documents"
        "Videos"

        # ======================================
        # Codes / Work / Playground
        # ======================================
        "projects"
        "nix-vault"
        "tmp"

        # android tools
        "Android"
        # Android Studio
        ".config/Google"
        ".android"

        # google gemini
        ".gemini"

        "Zotero"
        ".zotero"

        # Nutstore sync folder
        "nutstore_files"
        "Nutstore Files"
        ".nutstore"

        # lean prover
        ".elan"

        # some cache, like clipboard history, sccache, and Dolphin Anty's
        # runtime caches under `.cache/dolphin_anty` / `.cache/appimage-run`
        ".cache"

        # Warp config. The packaged Linux build is the OSS channel, whose
        # runtime app id uses the `warp-oss` XDG namespace.
        ".config/warp-terminal"
        ".config/warp-oss"

        # gnome configurations
        ".config/dconf"

        ".config/clash-nyanpasu"
        ".config/hiddify"
        ".config/flclash"

        # ======================================
        # Nix / Home Manager Profiles
        # ======================================

        ".local/state/home-manager"
        ".local/state/nix/profiles"
        ".local/share/nix"
        ".cache/nix"
        ".cache/nixpkgs-review"

        # ======================================
        # IDE / Editors
        # ======================================

        # doomemacs
        ".config/emacs"
        ".local/share/doom"
        ".local/share/emacs"
        "org" # org files

        # neovim plugins(wakatime & copilot)
        ".wakatime"
        ".config/github-copilot"

        # vscode
        ".vscode"
        ".config/Code"
        ".vscode-insiders"
        ".config/Code - Insiders"

        # godot
        ".config/godot"

        # nvidia profiling tools: nsight-system and nsight-compute
        ".config/NVIDIA Corporation/"
        ".nsightsystems"
        ".nsightcompute"

        # cursor ai editor
        ".cursor"
        ".config/cursor"
        ".config/Cursor"

        # zed editor
        ".config/zed"
        ".local/share/zed"

        # google ai editor (antigravity)
        ".config/Antigravity"
        ".antigravity"

        # ======================================
        # Unreal Engine / Epic Games
        # ======================================

        # Unreal/Epic store user config under `~/.config` (stateless root needs these persisted)
        ".config/Epic"
        ".config/Unreal Engine"

        # ai agents
        ".agents"
        ".config/agents"
        ".claude"
        ".grok"
        ".config/codex-desktop"
        ".config/Codex"
        ".codex"
        ".clawdbot"
        ".config/opencode"
        ".local/share/opencode"
        ".local/state/opencode"
        ".context7"
        ".kimi"
        ".local/state/codex-desktop"

        # nvim
        ".local/share/nvim"
        ".local/state/nvim"

        # helix & steel
        ".local/share/steel"

        # Joplin
        ".config/joplin" # tui client
        ".config/Joplin" # joplin-desktop

        # Dolphin Anty
        ".config/dolphin_anty"

        # Obsidian app-level system folder on Linux.
        # Vault-local `.obsidian` stays with the preserved vault directory itself.
        ".config/obsidian"

        ".local/share/jupyter"
        ".ipython"

        # qbittorrent
        ".config/qBittorrent"
        ".local/share/qBittorrent"
        ".yema"

        # vlc
        ".config/vlc/"
        # mpv
        ".config/mpv/"

        # wine
        ".wine"

        # ======================================
        # Cloud Native
        # ======================================
        {
          # pulumi - infrastructure as code
          directory = ".pulumi";
          mode = "0700";
        }
        {
          directory = ".aws";
          mode = "0700";
        }
        {
          directory = ".aliyun";
          mode = "0700";
        }
        {
          directory = ".config/gcloud";
          mode = "0700";
        }
        {
          directory = ".docker";
          mode = "0700";
        }
        {
          directory = ".kube";
          mode = "0700";
        }
        ".terraform.d/plugin-cache" # terraform's plugin cache

        # ======================================
        # language package managers
        # ======================================
        ".npm" # typsescript/javascript
        "go"
        ".cargo" # rust
        ".rustup"
        ".m2" # java maven
        ".gradle" # java gradle
        ".conda" # python generated by `conda-shell`
        # python pipx
        ".local/pipx"
        ".local/bin"
        # python uv
        ".local/share/uv"
        ".cache/uv"

        # ======================================
        # Security
        # ======================================

        {
          directory = ".gnupg";
          mode = "0700";
        }
        {
          directory = ".ssh";
          mode = "0700";
        }
        {
          directory = ".pki";
          mode = "0700";
        }

        ".local/share/password-store"
        # gnmome keyrings
        ".local/share/keyrings"

        # ======================================
        # Games / Media
        # ======================================

        "Games"
        ".steam"
        ".config/blender"
        ".config/LDtk"
        ".config/heroic"
        ".config/lutris"
        ".local/share/umu"

        ".local/share/Steam"
        ".local/state/Heroic"

        ".local/share/lutris"
        ".local/share/tiled"
        ".local/share/GOG.com"
        ".local/share/StardewValley"
        ".local/share/feral-interactive"
        ".local/share/orca-slicer"
        ".config/OrcaSlicer"

        # Bambu Studio - 3D Printer Slicer
        ".local/share/bambu-studio"
        ".config/BambuStudio"

        # ======================================
        # Meeting / Remote Desktop / Recording
        # ======================================
        ".zoom"
        ".config/obs-studio"
        ".config/sunshine"
        ".config/freerdp"

        ".config/remmina"
        ".local/share/remmina"

        # ======================================
        # browsers
        # ======================================
        ".mozilla"
        ".config/google-chrome"
        ".cache/google-chrome"
        ".config/chromium"
        ".cache/chromium"
        ".config/microsoft-edge"
        ".cache/microsoft-edge"
        ".config/RoxyBrowser"
        ".cache/RoxyBrowser"
        ".roxybrowser"

        # ======================================
        # CLI data
        # ======================================
        ".local/share/atuin"
        ".local/share/zoxide"
        ".local/share/direnv"
        ".local/share/k9s"
        ".cache/tealdeer" # tldr

        # ======================================
        # Containers
        # ======================================
        ".local/share/containers"
        ".local/share/flatpak"
        # flatpak/nixpak app's data
        ".var"

        # ======================================
        # xdg data home & state home
        # Used by:
        #  neovim, flatpak, autin, fcitx5, etc...
        # ======================================
        # XDG_DATA_HOME
        ".local/share"
        # XDG_STATE_HOME
        ".local/state"

        # ======================================
        # Misc
        # ======================================

        # Audio
        ".config/pulse"
        ".local/state/wireplumber"

        # flatpak app's data
        ".var"

        # Digital Painting
        ".local/share/krita"

        # Japanese IME
        ".config/mozc" # used by fcitx5-mozc

        ".config/nushell"
      ];
      files = [
        {
          file = ".wakatime.cfg";
          how = "symlink";
        }
        {
          file = ".config/zoomus.conf";
          how = "symlink";
        }
        {
          file = ".config/zoom.conf";
          how = "symlink";
        }
        {
          file = ".claude.json";
          how = "bindmount";
        }
      ];
    };
  };

  # Create some directories with custom permissions.
  #
  # In this configuration the path `/home/<user>/.local` is not an immediate parent
  # of any persisted file so it would be created with the systemd-tmpfiles default
  # ownership `root:root` and mode `0755`. This would mean that the user
  # could not create other files or directories inside `/home/<user>/.local`.
  #
  # Therefore systemd-tmpfiles is used to prepare such directories with
  # appropriate permissions.
  #
  # Note that immediate parent directories of persisted files can also be
  # configured with ownership and permissions from the `parent` settings if
  # `configureParent = true` is set for the file.
  systemd.tmpfiles.settings.preservation =
    let
      permission = {
        user = username;
        group = "users";
        mode = "0755";
      };
      homePermission = permission // {
        mode = "0700";
      };
    in
    {
      "/home/${username}".d = homePermission;
      "/home/${username}/.config".d = permission;
      "/home/${username}/.cache".d = permission;
      "/home/${username}/.local".d = permission;
      "/home/${username}/.local/share".d = permission;
      "/home/${username}/.local/state".d = permission;
      "/home/${username}/.local/state/nix".d = permission;
      "/home/${username}/.terraform.d".d = permission;
    };

  # systemd-machine-id-commit.service would fail but it is not relevant
  # in this specific setup for a persistent machine-id so we disable it
  #
  # see the firstboot example below for an alternative approach
  systemd.suppressedSystemUnits = [ "systemd-machine-id-commit.service" ];

  # let the service commit the transient ID to the persistent volume
  systemd.services.systemd-machine-id-commit = {
    unitConfig.ConditionPathIsMountPoint = [
      ""
      "/persistent/etc/machine-id"
    ];
    serviceConfig.ExecStart = [
      ""
      "systemd-machine-id-setup --commit --root /persistent"
    ];
  };
}
