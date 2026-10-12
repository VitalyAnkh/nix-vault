{ lib, outputs }:
let
  baseline = {
    sysctl = {
      "kernel.dmesg_restrict" = 1;
      "kernel.kptr_restrict" = 2;
      "kernel.yama.ptrace_scope" = 1;
      "kernel.perf_event_paranoid" = 2;
      "kernel.unprivileged_bpf_disabled" = 2;
      "net.core.bpf_jit_harden" = 1;
      "vm.unprivileged_userfaultfd" = 0;
      "fs.protected_symlinks" = 1;
      "fs.protected_hardlinks" = 1;
      "fs.protected_fifos" = 2;
      "fs.protected_regular" = 2;
    };
    allowUserNamespaces = true;
    hostOverride = 1;
  };

  # The libvirt/UVM-style akane host does not import the shared hardening
  # profile. Keep its intentional default values explicit rather than claiming
  # a global baseline that the host never enabled.
  akane = baseline // {
    sysctl = {
      "kernel.dmesg_restrict" = null;
      "kernel.kptr_restrict" = 1;
      "kernel.yama.ptrace_scope" = null;
      "kernel.perf_event_paranoid" = null;
      "kernel.unprivileged_bpf_disabled" = null;
      "net.core.bpf_jit_harden" = null;
      "vm.unprivileged_userfaultfd" = null;
      "fs.protected_symlinks" = null;
      "fs.protected_hardlinks" = null;
      "fs.protected_fifos" = null;
      "fs.protected_regular" = null;
    };
  };
in
lib.genAttrs (builtins.attrNames outputs.nixosConfigurations) (
  name: if name == "akane" then akane else baseline
)
