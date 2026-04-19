{ ... }:
{
  # Tune inotify limits to avoid "inotify handles exceeded" errors in
  # sync clients (e.g. Jianguoyun) when watching many directories.
  #
  # Note: NixOS has upstream defaults for these values; we keep them explicit
  # here so they are managed and auditable in this repo’s configuration.
  boot.kernel.sysctl = {
    # Some desktop workloads can exceed the old 524288-watch ceiling (for
    # example Warp alone was observed using ~523k), so keep the cap at the
    # kernel's signed-int maximum instead of repeatedly retuning it upward.
    "fs.inotify.max_user_watches" = 2147483647;
    "fs.inotify.max_user_instances" = 8192;
  };
}
