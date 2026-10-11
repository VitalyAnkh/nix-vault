{
  config,
  lib,
  pkgs,
  myvars,
  ...
}:
let
  cfg = config.modules.git.personalIdentity;
in
{
  options.modules.git.personalIdentity.enable =
    lib.mkEnableOption "the repository's personal Git identity, work include and GitHub URL rewrite"
    // {
      default = true;
    };

  # `programs.git` will generate the config file: ~/.config/git/config
  # to make git use this config file, `~/.gitconfig` should not exist!
  # Without the personal identity, ~/.gitconfig stays user-managed: Git reads it
  # after ~/.config/git/config, so the user's own settings keep precedence.
  #
  #    https://git-scm.com/docs/git-config#Documentation/git-config.txt---global
  config.home.activation.removeExistingGitconfig = lib.mkIf cfg.enable (
    lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
      run rm -f ${lib.escapeShellArg "${config.home.homeDirectory}/.gitconfig"}
    ''
  );

  # GitHub CLI tool
  # https://cli.github.com/manual/
  # Keep its configuration user-managed and persisted rather than replacing it
  # with a Home Manager-generated file on every activation.
  config.home.packages = [ pkgs.gh ];

  config.programs.git = {
    enable = true;
    package = pkgs.git;
    lfs.enable = true;
    signing.format = null;

    # signing = {
    #   key = "xxx";
    #   signByDefault = true;
    # };

    includes = lib.optionals cfg.enable [
      {
        # use different email & name for work:
        #
        # [user]
        #   email = "xxx@xxx.com"
        #   name = "VitalyR"
        path = "~/work/.gitconfig";
        condition = "gitdir:~/work/";
      }
    ];

    settings = {
      user.email = lib.mkIf cfg.enable myvars.useremail;
      user.name = lib.mkIf cfg.enable myvars.userfullname;

      init.defaultBranch = "main";
      trim.bases = "develop,master,main"; # for git-trim
      push.autoSetupRemote = true;
      pull.rebase = true;
      log.date = "iso"; # use iso format for date

      # replace https with ssh
      url = lib.mkIf cfg.enable {
        "ssh://git@github.com/VitalyAnkh" = {
          insteadOf = "https://github.com/VitalyAnkh";
        };
      };

      alias = {
        # common aliases
        br = "branch";
        co = "checkout";
        st = "status";
        ls = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate";
        ll = "log --pretty=format:\"%C(yellow)%h%Cred%d\\\\ %Creset%s%Cblue\\\\ [%cn]\" --decorate --numstat";
        cm = "commit -m"; # commit via `git cm <message>`
        ca = "commit -am"; # commit all changes via `git ca <message>`
        dc = "diff --cached";
        wt = "worktree";

        amend = "commit --amend -m"; # amend commit message via `git amend <message>`
        unstage = "reset HEAD --"; # unstage file via `git unstage <file>`
        merged = "branch --merged"; # list merged(into HEAD) branches via `git merged`
        unmerged = "branch --no-merged"; # list unmerged(into HEAD) branches via `git unmerged`
        nonexist = "remote prune origin --dry-run"; # list non-exist(remote) branches via `git nonexist`

        # delete merged branches except master & dev & staging
        #  `!` indicates it's a shell script, not a git subcommand
        delmerged = ''! git branch --merged | egrep -v "(^\*|main|master|dev|staging)" | xargs git branch -d'';
        # delete non-exist(remote) branches
        delnonexist = "remote prune origin";

        # aliases for submodule
        update = "submodule update --init --recursive";
        foreach = "submodule foreach";
      };
    };
  };

  # A syntax-highlighting pager for git, diff, grep, and blame output
  config.programs.delta = {
    enable = true;
    enableGitIntegration = true;
    options = {
      diff-so-fancy = true;
      line-numbers = true;
      true-color = "always";
      # features => named groups of settings, used to keep related settings organized
      # features = "";
    };
  };

  # Git terminal UI (written in go).
  config.programs.lazygit.enable = true;

  # Yet another Git TUI (written in rust).
  config.programs.gitui.enable = false;
}
