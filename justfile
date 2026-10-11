# just is a command runner with simpler syntax than Makefile.
# Keep this lowercase justfile as the canonical file when merging upstream changes.

# Use nushell for shell commands
# To use this justfile, you need to enter a shell with just & nushell installed:
#
#   nix shell nixpkgs#just nixpkgs#nushell
set shell := ["nu", "-c"]

utils_nu := absolute_path("utils.nu")

############################################################################
#
#  Common commands(suitable for all machines)
#
############################################################################

# List all the just commands
default:
    @just --list

[group('dev')]
config_latest_llvm:
  #!/usr/bin/env bash
  echo "==== config llvm-project ===="
  cd $HOME/projects/dev/cpp/llvm-project/
  git pull
  rm build/CMakeCache.txt
  rm build/NATIVE/CMakeCache.txt
  # -DMLIR_ENABLE_SYCL_RUNNER=1 \
  # -DMLIR_ENABLE_CUDA_CUSPARSE=1 \
  # plugin-api.h locates in /usr/include, to build LLVMgold.so plugin
  cmake -G Ninja -B build ./llvm \
    -DCMAKE_EXPORT_COMPILE_COMMANDS=ON \
    -DCMAKE_C_COMPILER_LAUNCHER=sccache \
    -DCMAKE_CXX_COMPILER_LAUNCHER=sccache \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_EXE_LINKER_FLAGS_INIT="-fuse-ld=mold" \
    -DCMAKE_MODULE_LINKER_FLAGS_INIT="-fuse-ld=mold" \
    -DCMAKE_SHARED_LINKER_FLAGS_INIT="-fuse-ld=mold" \
    -DCMAKE_INSTALL_PREFIX=$HOME/.local/opt/llvm@latest \
    -DCMAKE_BUILD_TYPE=RelWithDebInfo \
    -DLLVM_CCACHE_BUILD=ON \
    -DLLVM_USE_LINKER=mold \
    -DCMAKE_CXX_LINK_FLAGS="-Wl,-rpath,$LD_LIBRARY_PATH" \
    -DLLVM_TARGETS_TO_BUILD="X86;NVPTX;RISCV;AMDGPU" \
    -DLLVM_ENABLE_PROJECTS="clang;flang;llvm;mlir;lld;clang-tools-extra;lldb;bolt" \
    -DLLVM_ENABLE_RUNTIMES="openmp;compiler-rt;libcxx;libc;libcxxabi;libunwind;offload" \
    -DMLIR_ENABLE_BINDINGS_PYTHON=ON \
    -DMLIR_ENABLE_CUDA_RUNNER=1 \
    -DMLIR_ENABLE_SPIRV_CPU_RUNNER=1 \
    -DMLIR_INCLUDE_INTEGRATION_TESTS=1 \
    -DMLIR_RUN_CUDA_TENSOR_CORE_TESTS=1 \
    -DLLVM_LIT_ARGS=-v \
    -DLLVM_HAS_NVPTX_TARGET=1 \
    -DLLVM_OPTIMIZED_TABLEGEN=ON \
    -DLLVM_BUILD_UTILS=ON \
    -DLLVM_BUILD_TOOLS=ON \
    -DLLVM_INSTALL_UTILS=ON \
    -DLLVM_ENABLE_ASSERTIONS=ON \
    -DCMAKE_CXX_STANDARD=17
    # -DMLIR_ENABLE_CUDA_CUSPARSELT=1 \
    # -DLLVM_BINUTILS_INCDIR=/usr/include \
    # -DMLIR_ENABLE_VULKAN_RUNNER=1 \
  echo "==== config llvm-project done ===="

install_latest_llvm:
  #!/usr/bin/env bash
  echo "==== build newest llvm ===="
  cd $HOME/projects/dev/cpp/llvm-project/build
  cmake --build . -j$(nproc)
  cmake --install $HOME/projects/dev/cpp/llvm-project/build
  # ln -s /usr/local/opt/llvm@latest /usr/local/opt/llvm
  echo "==== build newest llvm done ===="

llvm_latest: config_latest_llvm install_latest_llvm

# Run eval tests
[group('nix')]
test:
  nix eval .#evalTests --show-trace --print-build-logs --verbose

# Evaluate a NixOS host configuration without building it.
[group('nix')]
eval-host host:
  nix eval $".#nixosConfigurations.{{host}}.config.system.build.toplevel.drvPath" --raw --show-trace

# Build a NixOS host system closure without changing the current system.
[group('nix')]
build-host host:
  nix build $".#nixosConfigurations.{{host}}.config.system.build.toplevel" --no-link --print-build-logs

# Build a MicroVM runner locally. Deploy it with microvm-deploy so the closure is copied remotely.
[group('nix')]
build-microvm guest:
  nix build $".#nixosConfigurations.{{guest}}.config.microvm.declaredRunner" --no-link --print-build-logs

# Update all the flake inputs
[group('nix')]
up:
  nix flake update --commit-lock-file

# Update specific input
# Usage: just upp nixpkgs
[group('nix')]
upp input:
  nix flake update {{input}} --commit-lock-file

# List all generations of the system profile
[group('nix')]
history:
  nix profile history --profile /nix/var/nix/profiles/system

# Open a nix shell with the flake
[group('nix')]
repl:
  nix repl -f flake:nixpkgs

# remove all generations older than 7 days
# on darwin, you may need to switch to root user to run this command
[group('nix')]
clean:
  # Wipe out NixOS's history
  sudo nix profile wipe-history --profile /nix/var/nix/profiles/system  --older-than 7d
  # Wipe out home-manager's history
  nix profile wipe-history --profile $"($env.XDG_STATE_HOME)/nix/profiles/home-manager" --older-than 7d

# Garbage collect all unused nix store entries
[group('nix')]
gc:
  # garbage collect all unused nix store entries(system-wide)
  sudo nix-collect-garbage --delete-older-than 7d
  # garbage collect all unused nix store entries(for the user - home-manager)
  # https://github.com/NixOS/nix/issues/8508
  nix-collect-garbage --delete-older-than 7d

# Enter a shell session which has all the necessary tools for this flake
[linux]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim nixpkgs#colmena

# Enter a shell session which has all the necessary tools for this flake
[macos]
[group('nix')]
shell:
  nix shell nixpkgs#git nixpkgs#neovim

# Upgrade Determinate Nix only; this is not the upstream/community Nix upgrade command.
[macos]
[group('nix')]
nix-upgrade:
  if (which determinate-nixd | is-empty) { error make {msg: "nix-upgrade requires Determinate Nix (determinate-nixd)"} }
  sudo determinate-nixd upgrade

[group('nix')]
fmt:
  # format the nix files in this repo
  # (use external find so symlinked dirs like the `result` build output are not followed)
  ^find . -name '*.nix' -not -path './.git/*' | lines | each { |it| nixfmt $it | ignore }

# Show all the auto gc roots in the nix store
[group('nix')]
gcroot:
  ls -al /nix/var/nix/gcroots/auto/

# Verify all the store entries
# Nix Store can contains corrupted entries if the nix store object has been modified unexpectedly.
# This command will verify all the store entries,
# and we need to fix the corrupted entries manually via `sudo nix store delete <store-path-1> <store-path-2> ...`
[group('nix')]
verify-store:
  nix store verify --all

# Repair Nix Store Objects
[group('nix')]
repair-store *paths:
  nix store repair {{paths}}

# Update all Nixpkgs inputs
[group('nix')]
up-nix:
  nix flake update --commit-lock-file nixpkgs-stable nixpkgs-master nixpkgs-darwin nixpkgs-patched

# override nixpkgs's commit hash
[group('nix')]
override-pkgs hash:
  nix flake update --commit-lock-file nixpkgs --override-input nixpkgs github:NixOS/nixpkgs/{{hash}}

############################################################################
#
#  NixOS Desktop related commands
#
############################################################################

# Deploy the nixosConfiguration by hostname match
[linux]
[group('homelab')]
local mode="switch" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch (hostname) {{mode}} {{verbosity}}

# Deploy the niri nixosConfiguration by hostname match
[linux]
[group('desktop')]
niri mode="switch" verbosity="normal":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  nixos-switch $"(hostname)-niri" {{mode}} {{verbosity}}

############################################################################
#
#  Darwin related commands
#
############################################################################

[macos]
[group('desktop')]
brew-upgrade:
  brew upgrade --cask --greedy

[macos]
[group('desktop')]
darwin-rollback:
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  darwin-rollback

# Deploy the darwinConfiguration matching the macOS HostName (jobs and cores: 1 to 16)
[macos]
[group('desktop')]
local verbosity="normal" jobs="1" cores="1":
  #!/usr/bin/env nu
  use {{utils_nu}} *;
  let name = (darwin-hostname)
  darwin-build $name {{quote(verbosity)}} --max-jobs {{jobs}} --cores {{cores}};
  darwin-switch $name


# Reset launchpad to force it to reindex Applications
[macos]
[group('desktop')]
reset-launchpad:
  defaults write com.apple.dock ResetLaunchPad -bool true
  killall Dock

# Test the Karabiner rule sync, then lint the rules if Karabiner-Elements is installed
[macos]
[group('desktop')]
karabiner-test:
  #!/usr/bin/env nu
  with-env { PYTHONDONTWRITEBYTECODE: "1" } {
    python3 -m unittest discover -s home/darwin/karabiner -p 'test_*.py'
  }
  let cli = "/Library/Application Support/org.pqrs/Karabiner-Elements/bin/karabiner_cli"
  if ($cli | path exists) {
    ^$cli --lint-complex-modifications home/darwin/karabiner/linux-shortcuts.json
  } else {
    print "karabiner_cli not found; skipped the rule lint"
  }

############################################################################
#
#  Homelab - VM host related commands
#
############################################################################

# Remote deployment via colmena
[linux]
[group('homelab')]
col tag mode="switch":
  colmena apply {{mode}} --on '@{{tag}}' --verbose --show-trace

# Deploy one microVM guest through microvm.nix's SSH deployment workflow.
# The host is the physical machine running the guest; the guest address is used for activation.
[linux]
[group('homelab')]
microvm-deploy guest host guest_ip:
  nix run $".#nixosConfigurations.{{guest}}.config.microvm.deploy.installOnHost" -- root@{{host}}
  nix run $".#nixosConfigurations.{{guest}}.config.microvm.deploy.sshSwitch" -- root@{{guest_ip}} --use-remote-sudo

# Deploy all the VM hosts (physical machines running the VMs)
[linux]
[group('homelab')]
lab mode="switch":
  colmena apply {{mode}} --on '@virt-*' --verbose --show-trace

[linux]
[group('homelab')]
shoryu mode="switch":
  colmena apply {{mode}} --on '@shoryu' --verbose --show-trace

[linux]
[group('homelab')]
shushou mode="switch":
  colmena apply {{mode}} --on '@shushou' --verbose --show-trace

[linux]
[group('homelab')]
youko mode="switch":
  colmena apply {{mode}} --on '@youko' --verbose --show-trace

############################################################################
#
# Commands for other Virtual Machines
#
############################################################################

[linux]
[group('homelab')]
ruby mode="switch":
  colmena apply {{mode}} --on '@ruby' --verbose --show-trace

[linux]
[group('homelab')]
kana mode="switch":
  colmena apply {{mode}} --on '@kana' --verbose --show-trace

############################################################################
#
# Kubernetes related commands
#
############################################################################

[linux]
[group('homelab')]
k3s-test mode="switch":
  colmena apply {{mode}} --on '@k3s-test-*' --verbose --show-trace

# =================================================
# Emacs related commands
# =================================================

[group('emacs')]
emacs-test:
  doom clean
  doom sync

[group('emacs')]
emacs-purge:
  doom purge
  doom clean
  doom sync

[linux]
[group('emacs')]
emacs-reload:
  doom sync
  systemctl --user restart emacs.service
  systemctl --user status emacs.service


emacs-plist-path := "~/Library/LaunchAgents/org.nix-community.home.emacs.plist"

[macos]
[group('emacs')]
emacs-reload:
  doom sync
  launchctl unload {{emacs-plist-path}}
  launchctl load {{emacs-plist-path}}
  tail -f ~/Library/Logs/emacs-daemon.stderr.log

# =================================================
#
# Other useful commands
#
# =================================================

[group('common')]
path:
   $env.PATH | split row ":"

[group('common')]
trace-access app *args:
  strace -f -t -e trace=file {{app}} {{args}} | complete | $in.stderr | lines | find -v -r "(/nix/store|/newroot|/proc)" | parse --regex '"(/.+)"' | sort | uniq

[linux]
[group('common')]
penvof pid:
  sudo cat $"/proc/($pid)/environ" | tr '\0' '\n'

# Remove all reflog entries and prune unreachable objects
[group('git')]
ggc:
  git reflog expire --expire-unreachable=now --all
  git gc --prune=now

# Amend the last commit without changing the commit message
[group('git')]
game:
  git commit --amend -a --no-edit

# Delete all failed pods
[group('k8s')]
del-failed:
  kubectl delete pod --all-namespaces --field-selector="status.phase==Failed"

[linux]
[group('services')]
list-inactive:
  systemctl list-units -all --state=inactive

[linux]
[group('services')]
list-failed:
  systemctl list-units -all --state=failed

[linux]
[group('services')]
list-systemd:
  systemctl list-units systemd-*


# =================================================
#
# GitHub CLI + Nixpkgs Review via Github Action
# (pass the repo explicitly, e.g. `OWNER/nixpkgs-review-gha`)
#
# =================================================

[group('github')]
gh-login:
  gh auth login -h github.com --skip-ssh-key --git-protocol ssh

# Run nixpkgs-review for PR
[group('nixpkgs')]
pkg-review pr repo:
  gh workflow run review.yml --repo {{repo}} -f x86_64-darwin=no -f post-result=true -f pr={{pr}}

# Run package tests for PR
[group('nixpkgs')]
pkg-test pr pname repo:
  gh workflow run review.yml --repo {{repo}} -f x86_64-darwin=no -f post-result=true -f pr={{pr}} -f extra-args="-p {{pname}}.passthru.tests"

# View the summary of a workflow
[group('nixpkgs')]
pkg-summary repo:
  gh workflow view review.yml --repo {{repo}}
