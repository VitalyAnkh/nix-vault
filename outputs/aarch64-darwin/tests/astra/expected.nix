{ inputs, myvars, ... }:
let
  user = (import "${inputs.mysecrets}/hosts/astra/account.nix").username;
  homeDirectory = "/Users/${user}";
in
{
  platform = "aarch64-darwin";
  hostname = "astra";
  primaryUser = user;
  users = [ user ];
  username = user;
  inherit homeDirectory;
  nixManaged = true;
  homebrew = {
    enable = true;
    cleanup = "check";
    autoUpdate = false;
    upgrade = false;
    usesBrewfile = true;
    shellIntegration = false;
    sharesMirrors = true;
    declaresHostApps = true;
    declaresHostFormulae = true;
    brewsAlsoFromNix = [ "fish" ];
    casksAlsoFromNix = [ ];
    taps = [ ];
  };
  shellEnvironment = {
    fishEnabled = true;
    fishLoadsSetEnvironment = true;
    fishRestoresNestedLoginPath = true;
    homebrewPaths = true;
    nixBeforeHomebrew = true;
    userToolPaths = true;
    privateEnvironmentPreserved = true;
    sharedAliases = true;
    grokBeforeCompletion = true;
    homebrewCompletionsAppended = true;
    zshCompinitOnce = true;
  };
  prompt = {
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
      disabled = false;
      format = "[$symbol $context( \\($namespace\\))]($style) ";
      contexts = [
        {
          context_pattern = "gke_.*_(?P<cluster>[\\w-]+)";
          context_alias = "$cluster";
        }
      ];
    };
  };
  managesSudoLocal = false;
  nixDaemon = {
    logFile = "/var/log/nix-daemon.log";
    substitutersUnique = true;
    trustsCacheNixosOrg = true;
    mirrorsAreFallback = true;
  };
  appendsSystemPaths = true;
  nodePackages = {
    npmrc = ''
      prefix=${homeDirectory}/.local/share/npm
      min-release-age=0
    '';
    pnpmConfig = ''
      globalDir: ${homeDirectory}/Library/pnpm/global
      globalBinDir: ${homeDirectory}/Library/pnpm/bin
      storeDir: ${homeDirectory}/Library/pnpm/store
      minimumReleaseAge: 0
      fetchTimeout: 300000
      fetchRetries: 5
      networkConcurrency: 2
    '';
    npmBinBeforeLocalBin = true;
  };
  packagePolicy = {
    openldapUsesUpstream = true;
    gnupgUsesUpstream = true;
    argocdUsesUpstream = true;
    zedUsesOfficialBinary = true;
    zedVersionAtLeastUpstream = true;
  };
  emacs = {
    enable = true;
    doom = true;
    daemon = false;
    installsDoom = true;
    linksDoom = true;
    fishFindsDoom = true;
    doomModules = true;
    doomSourcePatched = true;
    doomGitConfig = true;
  };
  karabiner = {
    enable = true;
    ruleAsset = true;
    managesMutableConfig = false;
    syncActivation = true;
    syncAfterWriteBoundary = true;
    syncFailureIsWarning = true;
    emacsHotkey = [
      {
        conditions = [
          {
            type = "frontmost_application_if";
            bundle_identifiers = [ "^org\\.gnu\\.Emacs$" ];
          }
        ];
        to = [
          {
            key_code = "h";
            modifiers = [ "left_command" ];
            repeat = false;
          }
        ];
      }
      {
        conditions = [ ];
        to = [
          {
            software_function.open_application.file_path = "~/Applications/Home Manager Apps/Emacs.app";
          }
        ];
      }
    ];
    syncAfterCopyApps = true;
    syncResolvesHome = true;
    assertions = [
      true
      true
    ];
    copyApps = {
      enable = true;
      directory = "Applications/Home Manager Apps";
    };
  };
  inputSourcePro = {
    enable = true;
    defaults = {
      systemWideDefaultKeyboardId = "com.apple.keylayout.ABC";
      isRestorePreviouslyUsedInputSource = false;
      isDetectSpotlightLikeApp = false;
      isCJKVFixEnabled = false;
      isActiveWhenLongpressLeftMouse = false;
      isLaunchAtLogin = true;
    };
  };
  personalConfig = {
    gitIdentity = false;
    setsGitName = false;
    setsGitEmail = false;
    gitIncludes = [ ];
    removesGitconfig = false;
    managesSsh = false;
    shipsSshKey = false;
    gpgKeys = [ ];
    gpgMutableKeys = true;
    gpgMutableTrust = true;
    setsPassEncryptionKey = false;
    setsPassSigningKey = false;
    workAliases = false;
    zai = false;
    managesRime = false;
    managesAerospace = false;
    managesProxy = false;
    installsZoteroObsidian = false;
  };
  standaloneUsers = [ "${myvars.username}@aarch64-darwin" ];
}
