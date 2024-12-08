{
  pkgs,
  lib,
  firefox,
  ...
}: {
  boot.loader.timeout = lib.mkForce 10; # wait for x seconds to select the boot entry

  environment.systemPackages = with pkgs; [
    wl-clipboard
    # VR_TODO: replace "x86_64-linux" with proper variable
    firefox.packages.x86_64-linux.firefox-nightly-bin
  ];
}
