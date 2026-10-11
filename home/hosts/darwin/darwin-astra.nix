{
  config,
  lib,
  mysecrets,
  osConfig,
  pkgs,
  pkgs-stable,
  ...
}:
let
  homeDir = config.home.homeDirectory;
  brewPrefix = osConfig.homebrew.prefix;
  # Work service addresses, proxy exceptions and client paths are not published:
  # they live in the private mysecrets repository.
  privateEnvironment = import "${mysecrets}/hosts/astra/environment.nix";
  setEnvironmentFish = pkgs.runCommandLocal "set-environment.fish" {
    nativeBuildInputs = [ pkgs.babelfish ];
  } ''babelfish < ${osConfig.system.build.setEnvironment} > "$out"'';
in
{
  imports = [ ../../darwin ];

  modules.editors.emacs = {
    enable = true;
    daemon.enable = false;
  };
  # Karabiner's Ctrl+Shift+Q rule opens Emacs.app, which needs Emacs without the daemon.
  modules.desktop.karabiner.enable = true;
  # Apps start with ABC; Control+Shift+8 switches to Shuangpin. The app is the
  # input-source-pro cask in hosts/darwin-astra/homebrew.nix.
  modules.desktop.inputSourcePro.enable = true;

  # Authentication and application-specific personal configuration stay local.
  modules.git.personalIdentity.enable = false;
  modules.ssh.personalConfig.enable = false;
  programs.ssh.enable = false;
  modules.gpg.personalIdentity.enable = false;
  modules.password-store.personalIdentity.enable = false;
  modules.shell.workAliases.enable = false;
  modules.shell.zai.enable = false;
  modules.desktop.squirrel.enable = false;
  modules.desktop.aerospace.enable = false;
  modules.desktop.proxy.enable = false;
  # Homebrew casks provide newer Zotero and Obsidian here; a second copy from
  # Home Manager would share their data directories.
  modules.desktop.academia.enable = false;

  # The prompt starts with user@host, which Starship otherwise shows only over SSH.
  # The kubectl context follows the directory: in Starship's default position it
  # leads the prompt, and its trailing "in" makes it read like a user name. A GKE
  # context (gke_<project>_<location>_<cluster>) shows only the cluster.
  programs.starship.settings = {
    format = "$username$hostname$directory$kubernetes$all";
    username = {
      show_always = true;
      format = "[$user]($style)@";
    };
    hostname = {
      ssh_only = false;
      format = "[$hostname]($style) in ";
    };
    kubernetes = {
      format = "[$symbol $context( \\($namespace\\))]($style) ";
      contexts = [
        {
          context_pattern = "gke_.*_(?P<cluster>[\\w-]+)";
          context_alias = "$cluster";
        }
      ];
    };
  };

  # npm's default global prefix is Node's own installation, and ~/.npm is its cache,
  # so global npm packages live in an XDG data directory instead. pnpm keeps its
  # existing macOS layout: the installed global packages record this store, and
  # pnpm refuses to update them from another one.
  modules.npm.prefix = "${config.xdg.dataHome}/npm";
  modules.pnpm = {
    globalDir = "${homeDir}/Library/pnpm/global";
    globalBinDir = "${homeDir}/Library/pnpm/bin";
    storeDir = "${homeDir}/Library/pnpm/store";
    virtualStoreDir = null;
  };

  # sessionPath is prepended to nix-darwin's PATH. Repeat its HM, system and default
  # profiles, in the same order, and place this list before the entries of shared
  # modules, so that neither Homebrew nor those directories shadow Nix packages.
  home.sessionPath = lib.mkBefore (
    [
      "${config.home.profileDirectory}/bin"
      "/run/current-system/sw/bin"
      "/nix/var/nix/profiles/default/bin"
      "${config.modules.npm.prefix}/bin"
      "${homeDir}/.local/bin"
      "${homeDir}/.elan/bin"
      config.modules.pnpm.globalBinDir
      "${homeDir}/.cargo/bin"
      "${homeDir}/go/bin"
    ]
    ++ map (dir: "${homeDir}/${dir}") privateEnvironment.sessionPath
    ++ [
      "${homeDir}/.grok/bin"
      "${brewPrefix}/bin"
      "${brewPrefix}/sbin"
    ]
  );
  home.sessionVariables =
    privateEnvironment.sessionVariables
    # The Homebrew mirrors that activation passes to `brew bundle`.
    // osConfig.homebrew.onActivation.extraEnv
    // {
      HOMEBREW_PREFIX = brewPrefix;
      HOMEBREW_CELLAR = "${brewPrefix}/Cellar";
      # On Apple Silicon, Homebrew's repository is its prefix.
      HOMEBREW_REPOSITORY = brewPrefix;
      # GitHub's HTTPS endpoint is often unreachable from astra's networks while SSH
      # works. Doom runs the git commands of `doom sync` with this global git
      # configuration, so its GitHub clones and updates use SSH.
      DOOMGITCONFIG = "${pkgs.writeText "doom-gitconfig" ''
        [url "git@github.com:"]
          insteadOf = https://github.com/
      ''}";
    };

  # Bash and Zsh load nix-darwin's set-environment from /etc. Fish does not: Warp
  # starts Homebrew's Fish, and nix-darwin's Fish module is off. Load it here before
  # Home Manager's session variables; its exported guard keeps child shells from
  # resetting PATH. This basename also masks the Nix installer's Homebrew Fish hook.
  xdg.configFile."fish/conf.d/nix.fish".text = ''
    if not set -q __NIX_DARWIN_SET_ENVIRONMENT_DONE
        set -l inherited_path $PATH
        source ${setEnvironmentFish}
        # Keep directories added by macOS or the terminal, such as Warp's CLI.
        fish_add_path --path --append $inherited_path
        # Put fish_user_paths back in front, as Fish does after macOS's path_helper.
        functions -q __fish_reconstruct_path; and __fish_reconstruct_path
    else if status is-login
        # A nested login shell, such as a multiplexer pane, inherits this PATH, but
        # Fish's path_helper step has moved the macOS directories in front of it.
        fish_add_path --path --move ${lib.escapeShellArgs config.home.sessionPath}
        functions -q __fish_reconstruct_path; and __fish_reconstruct_path
    end
  '';

  # HM initializes completion once at order 570, after these optional paths. They
  # are appended so that Nix packages' completions take precedence, as on PATH.
  programs.zsh.initContent = lib.mkOrder 550 ''
    if [[ -d ${brewPrefix}/share/zsh/site-functions ]]; then
      fpath+=(${brewPrefix}/share/zsh/site-functions)
    fi
    if [[ -d "$HOME/.grok/completions/zsh" ]]; then
      fpath+=("$HOME/.grok/completions/zsh")
    fi
  '';

  # Zed's official signed app, at the version of nixpkgs' Zed, without a Rust build.
  programs.zed-editor.package = pkgs.zed-editor-bin;

  # Start the language servers that the shared Nixvim module declares.
  programs.nixvim.plugins.lsp.enable = true;

  # The pinned Nixvim release targets the 26.05 package set.
  programs.nixvim.nixpkgs = {
    useGlobalPackages = lib.mkForce false;
    # Reuse the system's Node fix within Nixvim's stable package set.
    pkgs = pkgs-stable.extend (
      _final: _prev: {
        nodejs-slim_24 = pkgs.nodejs-slim_24;
        # The core uses Node only in its checks; runtime tools retain patched Node.
        neovim-unwrapped = pkgs-stable.neovim-unwrapped;
      }
    );
  };
}
