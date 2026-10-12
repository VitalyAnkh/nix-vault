def repeat-str [s: string, n: int] {
  (1..$n | each { $s } | str join)
}

# ================= NixOS related =========================

export def nixos-switch [
    name: string
    mode: string
    verbosity: string
] {
    if $mode not-in ["switch" "boot"] {
        error make { msg: $"unsupported deployment mode '($mode)'; expected switch or boot" }
    }
    if $verbosity not-in ["normal" "debug"] {
        error make { msg: $"unsupported verbosity '($verbosity)'; expected normal or debug" }
    }

    print $"nixos-switch '($name)' in '($mode)' mode with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    if $verbosity == "debug" {
        # show details via nix-output-monitor
        nom build $".#nixosConfigurations.($name).config.system.build.toplevel" --accept-flake-config --show-trace --verbose
        nixos-rebuild $mode --sudo --flake $".#($name)" --accept-flake-config --show-trace --verbose
    } else {
        nixos-rebuild $mode --sudo --flake $".#($name)" --accept-flake-config
    }
}


# ====================== Misc =============================

export def make-editable [
    path: string
] {
    print (repeat-str "=" 50)
    let tmpdir = (mktemp -d)
    rsync -avz --copy-links $"($path)/" $tmpdir
    rsync -avz --copy-links --chmod=D2755,F744 $"($tmpdir)/" $path
}


# ================= macOS related =========================

# nix-darwin sets HostName from networking.hostName. Bonjour renames LocalHostName
# (astra-2) when another device on the network claims it, so LocalHostName is only
# the fallback before the first activation.
export def darwin-hostname [] {
    for key in [HostName LocalHostName] {
        let result = (/usr/sbin/scutil --get $key | complete)
        let name = ($result.stdout | str trim)
        if $result.exit_code == 0 and ($name | is-not-empty) {
            return $name
        }
    }
    error make { msg: "macOS HostName and LocalHostName are unset; set one before running just local" }
}

def validate-darwin-verbosity [verbosity: string] {
    if $verbosity not-in ["normal" "debug"] {
        error make { msg: $"unsupported verbosity '($verbosity)'; expected normal or debug" }
    }
}

# Builds stay within the repository's ceiling of 16 jobs and 16 cores (AGENTS.md);
# Nix would read --cores 0 as all cores.
def validate-build-limit [flag: string value: int] {
    if $value < 1 or $value > 16 {
        error make { msg: $"unsupported --($flag) ($value); expected 1 to 16" }
    }
}

export def darwin-build [
    name: string
    verbosity: string
    --max-jobs: int = 1
    --cores: int = 1
] {
    validate-darwin-verbosity $verbosity
    validate-build-limit max-jobs $max_jobs
    validate-build-limit cores $cores
    print $"darwin-build '($name)' with '($verbosity)' verbosity..."
    print (repeat-str "=" 50)
    let target = $".#darwinConfigurations.($name).system"
    let out_link = $"result-($name)"
    try {
        if "debug" == $verbosity {
            nom build $target --out-link $out_link --extra-experimental-features "nix-command flakes" --no-write-lock-file --max-jobs $max_jobs --cores $cores --show-trace --verbose
        } else {
            nix build $target --out-link $out_link --extra-experimental-features "nix-command flakes" --no-write-lock-file --max-jobs $max_jobs --cores $cores
        }
    } catch {
        error make { msg: $"darwin-build '($name)' failed; refusing to switch an existing output" }
    }
}

export def darwin-switch [
    name: string
] {
    let rebuild = $"./result-($name)/sw/bin/darwin-rebuild"
    if not ($rebuild | path exists) {
        error make { msg: $"no built nix-darwin system at result-($name); run darwin-build first" }
    }
    let system = ($"result-($name)" | path expand)
    # Like the pinned darwin-rebuild: use the system's Nix, or the installer's
    # default profile on hosts that leave nix.enable off.
    let nix_env = (
        [$"($system)/sw/bin/nix-env" "/nix/var/nix/profiles/default/bin/nix-env"]
        | where {|candidate| $candidate | path exists }
        | get 0?
    )
    if $nix_env == null {
        error make { msg: $"no nix-env in ($system) or the default Nix profile" }
    }
    print $"darwin-switch '($name)' to ($system)..."
    print (repeat-str "=" 50)
    # Activate exactly the system darwin-build produced, with the two steps the pinned
    # `darwin-rebuild switch` runs after its build (recheck them after nix-darwin
    # updates). Switching with --flake would re-evaluate as root, and root cannot
    # fetch the private mysecrets input over SSH. As in darwin-rebuild, root keeps
    # its own HOME and uses the daemon.
    try {
        sudo -H env NIX_REMOTE=daemon $nix_env -p /nix/var/nix/profiles/system --set $system
    } catch {
        error make { msg: $"failed to set the system profile to ($system); not activating" }
    }
    sudo -H $"($system)/sw/bin/darwin-rebuild" activate
}

export def darwin-rollback [] {
    let rebuild = "/run/current-system/sw/bin/darwin-rebuild"
    if not ($rebuild | path exists) {
        error make { msg: "no activated nix-darwin system at /run/current-system; rollback requires a previous activation" }
    }
    # darwin-rebuild refuses rollback unless it runs as root. Use the activated
    # system rather than a stale build result, while preserving the environment.
    sudo -E $rebuild --rollback
}
