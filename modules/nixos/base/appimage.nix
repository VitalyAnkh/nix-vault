{ pkgs, ... }:
let
  baseAppImageRun = pkgs.appimage-run;

  # Some Chromium/Electron AppImages crash on native Wayland with NVIDIA due
  # to dmabuf/EGL import failures. Fall back to XWayland only for the known
  # affected browser AppImages while leaving other AppImages unchanged.
  appImageRunWrapped = pkgs.symlinkJoin {
    name = "appimage-run-wrapped";
    paths = [ baseAppImageRun ];
    meta = (baseAppImageRun.meta or { }) // {
      mainProgram = "appimage-run";
    };
    postBuild = ''
      rm "$out/bin/appimage-run"
      cat > "$out/bin/appimage-run" <<'EOF'
      #!${pkgs.runtimeShell}
      set -euo pipefail

      appimage_path="''${1-}"
      appimage_name=""

      if [ -n "$appimage_path" ]; then
        appimage_name="$(basename "$appimage_path" | tr '[:upper:]' '[:lower:]')"
      fi

      force_x11=0
      if [ "''${XDG_SESSION_TYPE-}" = "wayland" ] && [ -e /proc/driver/nvidia/version ]; then
        case "$appimage_name" in
          *dolphin*|*gologin*|*orbita*)
            force_x11=1
            ;;
        esac
      fi

      if [ "$force_x11" -eq 1 ]; then
        export NIXOS_OZONE_WL=0
        export ELECTRON_OZONE_PLATFORM_HINT=x11
        export GDK_BACKEND=x11
        export QT_QPA_PLATFORM=xcb
        export SDL_VIDEODRIVER=x11
        exec ${baseAppImageRun}/bin/appimage-run "$@" --ozone-platform=x11
      fi

      exec ${baseAppImageRun}/bin/appimage-run "$@"
      EOF
      chmod 0755 "$out/bin/appimage-run"
    '';
  };
in
{
  environment.systemPackages = [
    # convenient for debugging & manual launching besides the binfmt handler below
    appImageRunWrapped
  ];

  # allow AppImage files to be executed directly via binfmt/appimage-run
  programs.appimage = {
    enable = true;
    binfmt = true;
    package = appImageRunWrapped;
  };
}
