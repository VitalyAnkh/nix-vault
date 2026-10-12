{ inputs, outputs, ... }:
let
  darwin = outputs.darwinConfigurations.astra;
  system = darwin.config;
  home = system.home-manager.users.${system.system.primaryUser};
  inherit (darwin.pkgs) lib;
  privateEnvironment = import "${inputs.mysecrets}/hosts/astra/environment.nix";
  upstreamPkgs = import darwin.pkgs.path {
    inherit (darwin.pkgs.stdenv.hostPlatform) system;
    inherit (darwin.pkgs) config;
    overlays = [ ];
  };
  fishNixConfig = home.xdg.configFile."fish/conf.d/nix.fish".text or "";
  brewNames = map (brew: brew.name) system.homebrew.brews;
  caskNames = map (cask: cask.name) system.homebrew.casks;
  nixPackages = system.environment.systemPackages ++ home.home.packages;
  nixNames = lib.unique (
    map lib.getName nixPackages ++ map (package: package.meta.mainProgram or "") nixPackages
  );
in
{
  platform = darwin.pkgs.stdenv.hostPlatform.system;
  hostname = system.networking.hostName;
  primaryUser = system.system.primaryUser;
  users = builtins.attrNames system.home-manager.users;
  username = home.home.username;
  homeDirectory = home.home.homeDirectory;
  nixManaged = system.nix.enable;
  homebrew = {
    inherit (system.homebrew) enable;
    # Activation installs missing entries only; it never removes or upgrades.
    inherit (system.homebrew.onActivation) cleanup autoUpdate upgrade;
    usesBrewfile = system.homebrew.global.brewfile;
    # nix-darwin does not run `brew shellenv`, which would put Homebrew before Nix.
    shellIntegration = builtins.any (shell: system.homebrew."enable${shell}Integration") [
      "Bash"
      "Fish"
      "Zsh"
    ];
    # Interactive shells use the same Homebrew mirrors as activation.
    sharesMirrors =
      system.homebrew.onActivation.extraEnv ? HOMEBREW_API_DOMAIN
      && builtins.all (
        name: (home.home.sessionVariables.${name} or null) == system.homebrew.onActivation.extraEnv.${name}
      ) (builtins.attrNames system.homebrew.onActivation.extraEnv);
    # Apps that this configuration relies on, or leaves to Homebrew, are declared.
    declaresHostApps = builtins.all (cask: builtins.elem cask caskNames) [
      "input-source-pro"
      "karabiner-elements"
      "obsidian"
      "warp"
      "zotero"
    ];
    # So are formulae used outside PATH: a library and a `brew services` server.
    declaresHostFormulae = builtins.all (brew: builtins.elem brew brewNames) [
      "libomp"
      "postgresql@17"
    ];
    # Each tool has one source; only Warp's Fish is also provided by Nix.
    brewsAlsoFromNix = lib.intersectLists nixNames brewNames;
    casksAlsoFromNix = lib.intersectLists nixNames caskNames;
    taps = map (tap: tap.name) system.homebrew.taps;
  };
  shellEnvironment = {
    fishEnabled = home.programs.fish.enable;
    # Fish runs nix-darwin's set-environment, guarded like nix-darwin's /etc files.
    fishLoadsSetEnvironment =
      lib.hasPrefix "if not set -q __NIX_DARWIN_SET_ENVIRONMENT_DONE\n" fishNixConfig
      && lib.hasInfix "source /nix/store/" fishNixConfig
      && lib.hasInfix "-set-environment.fish\n" fishNixConfig;
    # Nested login shells put sessionPath back in front of path_helper's entries.
    fishRestoresNestedLoginPath =
      lib.hasInfix "\nelse if status is-login\n" fishNixConfig
      && lib.hasInfix "fish_add_path --path --move ${lib.escapeShellArgs home.home.sessionPath}\n" fishNixConfig;
    homebrewPaths = builtins.all (path: builtins.elem path home.home.sessionPath) [
      "/opt/homebrew/bin"
      "/opt/homebrew/sbin"
    ];
    # The HM, system and default profiles come first, in set-environment's order,
    # and precede Homebrew.
    nixBeforeHomebrew =
      let
        nixPaths = [
          "${home.home.profileDirectory}/bin"
          "/run/current-system/sw/bin"
          "/nix/var/nix/profiles/default/bin"
        ];
        orderedPaths = builtins.filter (
          path: builtins.elem path (nixPaths ++ [ "/opt/homebrew/bin" ])
        ) home.home.sessionPath;
      in
      lib.take 3 home.home.sessionPath == nixPaths && orderedPaths == nixPaths ++ [ "/opt/homebrew/bin" ];
    userToolPaths = builtins.all (path: builtins.elem path home.home.sessionPath) (
      map (path: "${home.home.homeDirectory}/${path}") [
        ".local/bin"
        ".elan/bin"
        "Library/pnpm/bin"
        ".cargo/bin"
        "go/bin"
        ".grok/bin"
      ]
    );
    # The private work environment is applied in full; an empty file would hide a
    # missing or stale mysecrets input.
    privateEnvironmentPreserved =
      privateEnvironment.sessionVariables != { }
      && builtins.all (
        name: (home.home.sessionVariables.${name} or null) == privateEnvironment.sessionVariables.${name}
      ) (builtins.attrNames privateEnvironment.sessionVariables)
      && builtins.all (
        dir: builtins.elem "${home.home.homeDirectory}/${dir}" home.home.sessionPath
      ) privateEnvironment.sessionPath;
    sharedAliases = builtins.all (shell: shell.shellAliases.k == "kubectl") [
      home.programs.bash
      home.programs.zsh
      home.programs.fish
    ];
    grokBeforeCompletion = lib.hasInfix "$HOME/.grok/completions/zsh" (
      builtins.head (lib.splitString home.programs.zsh.completionInit home.programs.zsh.initContent)
    );
    # Homebrew's completions follow those of Nix packages, as on PATH.
    homebrewCompletionsAppended = lib.hasInfix "fpath+=(/opt/homebrew/share/zsh/site-functions)" home.programs.zsh.initContent;
    # Only Home Manager's .zshrc runs compinit, not /etc/zshrc as well.
    zshCompinitOnce = !system.programs.zsh.enableGlobalCompInit && home.programs.zsh.enableCompletion;
  };
  # The prompt starts with user@host; the kubectl context follows the directory.
  prompt = {
    inherit (home.programs.starship.settings) format username hostname;
    kubernetes = {
      inherit (home.programs.starship.settings.kubernetes) disabled format contexts;
    };
  };
  # /etc/pam.d/sudo_local stays unmanaged: nothing is written under /etc/pam.d.
  managesSudoLocal = system.security.pam.services.sudo_local.enable;
  nixDaemon = {
    inherit (system.services.nix-daemon) logFile;
    # Each cache appears once, compared without `?priority=` or a trailing slash:
    # nix-darwin adds https://cache.nixos.org/ and its key itself. The China mirrors
    # only back up the others.
    substitutersUnique = lib.allUnique (
      map (
        substituter: lib.removeSuffix "/" (builtins.head (lib.splitString "?" substituter))
      ) system.nix.settings.substituters
    );
    trustsCacheNixosOrg = builtins.elem "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY=" system.nix.settings.trusted-public-keys;
    mirrorsAreFallback = builtins.all (lib.hasSuffix "?priority=50") (
      builtins.filter (lib.hasInfix "/nix-channels/store") system.nix.settings.substituters
    );
  };
  # Zsh and Bash keep the directories from /etc/paths and /etc/paths.d.
  appendsSystemPaths = lib.hasInfix "-append-system-paths \"$PATH\")" system.environment.extraInit;
  # Global npm packages live in an XDG data directory whose commands precede
  # ~/.local/bin; pnpm keeps the macOS layout and store its packages record.
  nodePackages = {
    npmrc = home.home.file.".npmrc".text;
    pnpmConfig = home.home.file.".config/pnpm/config.yaml".text;
    npmBinBeforeLocalBin =
      let
        position = path: lib.lists.findFirstIndex (entry: entry == path) null home.home.sessionPath;
      in
      position "${home.home.homeDirectory}/.local/share/npm/bin"
      < position "${home.home.homeDirectory}/.local/bin";
  };
  packagePolicy = {
    openldapUsesUpstream = darwin.pkgs.openldap.drvPath == upstreamPkgs.openldap.drvPath;
    gnupgUsesUpstream = darwin.pkgs.gnupg.drvPath == upstreamPkgs.gnupg.drvPath;
    argocdUsesUpstream = darwin.pkgs.argocd.drvPath == upstreamPkgs.argocd.drvPath;
    zedUsesOfficialBinary =
      home.programs.zed-editor.package.drvPath == darwin.pkgs.zed-editor-bin.drvPath;
    # zed-editor-bin follows Zed's newest stable release, never older than nixpkgs' build.
    zedVersionAtLeastUpstream = lib.versionAtLeast home.programs.zed-editor.package.version upstreamPkgs.zed-editor.version;
  };
  emacs = {
    inherit (home.modules.editors.emacs) enable;
    doom = home.modules.editors.emacs.doom.enable;
    daemon = home.modules.editors.emacs.daemon.enable;
    installsDoom = home.home.activation ? installDoomEmacs;
    linksDoom = home.xdg.configFile ? doom;
    # Fish, like Bash and Zsh, finds Doom's `doom` command.
    fishFindsDoom = lib.hasInfix "fish_add_path --path ${lib.escapeShellArg "${home.xdg.configHome}/emacs/bin"}\n" home.programs.fish.shellInit;
    # The Doom source includes its modules, the git submodule sources/doom+.
    doomModules = builtins.pathExists "${inputs.doomemacs}/sources/doom+/modules/ui/doom";
    # Activation copies the patched Doom source.
    doomSourcePatched = lib.hasInfix "-doomemacs/" home.home.activation.installDoomEmacs.data;
    # `doom sync` reaches GitHub over SSH.
    doomGitConfig = lib.hasSuffix "-doom-gitconfig" (home.home.sessionVariables.DOOMGITCONFIG or "");
  };
  karabiner = {
    enable = home.modules.desktop.karabiner.enable;
    ruleAsset =
      home.xdg.configFile ? "karabiner/assets/complex_modifications/nix-vault-linux-shortcuts.json";
    # Neither karabiner.json nor its directory is a read-only Home Manager link.
    managesMutableConfig = builtins.any (
      file:
      builtins.elem file.target [
        ".config/karabiner"
        ".config/karabiner/karabiner.json"
      ]
    ) (builtins.attrValues home.home.file);
    syncActivation = home.home.activation ? syncKarabiner;
    syncAfterWriteBoundary = builtins.elem "writeBoundary" home.home.activation.syncKarabiner.after;
    syncFailureIsWarning = lib.hasInfix "|| warnEcho" home.home.activation.syncKarabiner.data;
    # Ctrl+Shift+Q hides Emacs when it is frontmost and otherwise opens the copy that
    # copyApps maintains; the sync resolves ~/ against the home directory.
    emacsHotkey =
      let
        asset =
          lib.importJSON
            home.xdg.configFile."karabiner/assets/complex_modifications/nix-vault-linux-shortcuts.json".source;
        hotkey = lib.findFirst (rule: rule.description == "Nix Vault: All profiles: Emacs global hotkey") {
          manipulators = [ ];
        } asset.rules;
      in
      map (manipulator: {
        conditions = manipulator.conditions or [ ];
        inherit (manipulator) to;
      }) hotkey.manipulators;
    syncAfterCopyApps = builtins.elem "copyApps" home.home.activation.syncKarabiner.after;
    syncResolvesHome =
      let
        sync = lib.findFirst (
          package: lib.getName package == "nix-vault-karabiner-sync"
        ) null home.home.packages;
      in
      sync != null && lib.hasInfix "--home ${lib.escapeShellArg home.home.homeDirectory} \\\n" sync.text;
    # Both module assertions exist and hold; an empty list would also be "all true".
    assertions = map (assertion: assertion.assertion) (
      builtins.filter (
        assertion: lib.hasPrefix "modules.desktop.karabiner:" assertion.message
      ) home.assertions
    );
    # The hotkey's target is the copy that copyApps maintains in this directory.
    copyApps = { inherit (home.targets.darwin.copyApps) enable directory; };
  };
  # Input Source Pro selects ABC whenever an app becomes active and never selects
  # Shuangpin itself, so it needs no privacy permissions.
  inputSourcePro = {
    inherit (home.modules.desktop.inputSourcePro) enable;
    defaults = home.targets.darwin.defaults."com.runjuu.Input-Source-Pro";
  };
  personalConfig = {
    gitIdentity = home.modules.git.personalIdentity.enable;
    setsGitName = home.programs.git.settings ? user.name;
    setsGitEmail = home.programs.git.settings ? user.email;
    gitIncludes = home.programs.git.includes;
    removesGitconfig = home.home.activation ? removeExistingGitconfig;
    managesSsh = home.programs.ssh.enable;
    shipsSshKey = home.home.file ? ".ssh/romantic.pub";
    gpgKeys = home.programs.gpg.publicKeys;
    gpgMutableKeys = home.programs.gpg.mutableKeys;
    gpgMutableTrust = home.programs.gpg.mutableTrust;
    setsPassEncryptionKey = home.programs.password-store.settings ? PASSWORD_STORE_KEY;
    setsPassSigningKey = home.programs.password-store.settings ? PASSWORD_STORE_SIGNING_KEY;
    workAliases = home.modules.shell.workAliases.enable;
    zai = home.modules.shell.zai.enable;
    managesRime = home.home.file ? "Library/Rime";
    managesAerospace = home.home.file ? ".aerospace.toml";
    managesProxy = home.home.file ? ".proxychains/proxychains.conf";
    # Homebrew casks provide these apps on astra.
    installsZoteroObsidian = builtins.any (
      package:
      builtins.elem (package.pname or "") [
        "zotero"
        "obsidian"
      ]
    ) home.home.packages;
  };
  standaloneUsers = builtins.attrNames outputs.homeConfigurations;
}
