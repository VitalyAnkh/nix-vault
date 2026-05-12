{
  pkgs,
  lib ? pkgs.lib,
  ...
}:

let
  isLinux = pkgs.stdenv.hostPlatform.isLinux;

  packageMeta = {
    description = "Local Unreal Engine 5 wrapper with FHS runtime helpers";
    homepage = "https://www.unrealengine.com/";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
  };

  linuxPackage =
    let
      deps = with pkgs; [
        openssl
        zlib
      ];

      tools = with pkgs; [
        bash
        coreutils
        findutils
        gnugrep
        gawk
        gnused
        which
        git
        curl
        wget
        gnutar
        gzip
        python3
        cmake
        ninja
        gnumake
        unzip
        zip
        rsync
        perl
        patchelf
      ];

      unrealFhs = pkgs.buildFHSEnv {
        name = "ue5-fhs";

        targetPkgs =
          pkgs:
          tools
          ++ deps
          ++ (with pkgs; [
            udev
            alsa-lib
            icu
            SDL2
            vulkan-loader
            vulkan-tools
            vulkan-validation-layers
            glib
            libxkbcommon
            nss
            nspr
            atk
            mesa
            dbus
            pango
            cairo
            libpulseaudio
            libGL
            libgbm
            expat
            libdrm
            wayland
          ])
          ++ (with pkgs; [
            libice
            libsm
            libx11
            libxcb
            libxcomposite
            libxcursor
            libxdamage
            libxext
            libxfixes
            libxi
            libxrandr
            libxrender
            libxscrnsaver
            libxshmfence
            libxtst
          ]);

        runScript = "bash";
        NIX_LD_LIBRARY_PATH = lib.makeLibraryPath deps;
        NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";
        nativeBuildInputs = deps;
      };

      localUnrealEditor = pkgs.writeShellScriptBin "UnrealEditor" ''
        set -euo pipefail

        export PATH="${
          lib.makeBinPath [
            pkgs.coreutils
            pkgs.gnugrep
            pkgs.iproute2
          ]
        }:''${PATH-}"

        if [[ "$(id -u)" -eq 0 ]]; then
          echo "ERROR: Run this as an unprivileged user; not as root." >&2
          exit 1
        fi

        maybe_force_sdl_videodriver() {
          if [[ -n "''${UE_SDL_VIDEODRIVER:-}" ]]; then
            export SDL_VIDEODRIVER="''${UE_SDL_VIDEODRIVER}"
            echo "UE SDL: SDL_VIDEODRIVER set from UE_SDL_VIDEODRIVER=$UE_SDL_VIDEODRIVER" >&2
            return 0
          fi

          if [[ -n "''${SDL_VIDEODRIVER:-}" && "''${SDL_VIDEODRIVER}" != "wayland" ]]; then
            return 0
          fi

          if [[ -n "''${WAYLAND_DISPLAY:-}" || "''${XDG_SESSION_TYPE:-}" == "wayland" ]]; then
            if [[ -n "''${DISPLAY:-}" && -e /proc/driver/nvidia/version ]]; then
              local prev_sdl_videodriver
              prev_sdl_videodriver="''${SDL_VIDEODRIVER:-<unset>}"
              export SDL_VIDEODRIVER="x11"
              echo "UE SDL: forcing SDL_VIDEODRIVER=x11 (Wayland+NVIDIA Vulkan WSI crash workaround; was: $prev_sdl_videodriver)" >&2
            fi
          fi
        }

        maybe_force_allocator_args() {
          local mode
          mode="''${UE_MALLOC_MODE:-auto}"
          case "$mode" in
            auto|mimalloc|binned2|binned|ansi|jemalloc|none) ;;
            *) mode="auto" ;;
          esac

          local arg
          for arg in "$@"; do
            case "$arg" in
              -ansimalloc|-binnedmalloc|-binnedmalloc2|-mimalloc|-jemalloc)
                return 0
                ;;
            esac
          done

          local flag
          flag=""
          case "$mode" in
            none) flag="" ;;
            mimalloc) flag="-mimalloc" ;;
            binned2) flag="-binnedmalloc2" ;;
            binned) flag="-binnedmalloc" ;;
            ansi) flag="-ansimalloc" ;;
            jemalloc) flag="-jemalloc" ;;
            auto)
              if [[ -e /proc/driver/nvidia/version ]]; then
                flag="-binnedmalloc2"
              fi
              ;;
          esac

          if [[ -n "$flag" ]]; then
            echo "UE malloc: adding allocator switch $flag (UE_MALLOC_MODE=$mode)" >&2
            printf '%s\n' "$flag"
          fi
        }

        maybe_force_vulkan_present_mode_args() {
          local mode
          mode="''${UE_VULKAN_PRESENT_MODE:-auto}"
          case "$mode" in
            auto|fifo|mailbox|immediate|none) ;;
            *) mode="auto" ;;
          esac

          local arg
          for arg in "$@"; do
            case "$arg" in
              *vulkanpresentmode=*)
                return 0
                ;;
            esac
          done

          local present_mode
          present_mode=""
          case "$mode" in
            none) present_mode="" ;;
            fifo) present_mode="2" ;;
            mailbox) present_mode="1" ;;
            immediate) present_mode="0" ;;
            auto)
              if [[ -e /proc/driver/nvidia/version ]]; then
                present_mode="2"
              fi
              ;;
          esac

          if [[ -n "$present_mode" ]]; then
            echo "UE Vulkan: forcing present mode (-vulkanpresentmode=$present_mode) (UE_VULKAN_PRESENT_MODE=$mode)" >&2
            printf '%s\n' "-vulkanpresentmode=$present_mode"
          fi
        }

        maybe_force_cvarsini_args() {
          local arg
          for arg in "$@"; do
            case "$arg" in
              -cvarsini=*)
                return 0
                ;;
            esac
          done

          local want_file
          want_file=0

          local -a cvars_lines
          cvars_lines=()

          local timeline_mode
          timeline_mode="''${UE_VULKAN_TIMELINE_SEMAPHORES:-auto}"
          case "$timeline_mode" in
            auto|on|off|none) ;;
            *) timeline_mode="auto" ;;
          esac
          if [[ "$timeline_mode" == "auto" && -e /proc/driver/nvidia/version ]]; then
            timeline_mode="off"
          fi
          if [[ "$timeline_mode" == "off" ]]; then
            want_file=1
            cvars_lines+=("r.Vulkan.Submission.AllowTimelineSemaphores=0")
          fi

          local cef_mode
          cef_mode="''${UE_CEF_GPU_ACCELERATION:-auto}"
          case "$cef_mode" in
            auto|on|off|none) ;;
            *) cef_mode="auto" ;;
          esac
          if [[ "$cef_mode" == "auto" ]]; then
            if [[ -e /proc/driver/nvidia/version ]] && grep -q "Open Kernel Module" /proc/driver/nvidia/version 2>/dev/null; then
              cef_mode="off"
            else
              cef_mode="none"
            fi
          fi
          case "$cef_mode" in
            on)
              want_file=1
              cvars_lines+=("r.CEFGPUAcceleration=1")
              ;;
            off)
              want_file=1
              cvars_lines+=("r.CEFGPUAcceleration=0")
              ;;
          esac

          local gpu_safe_mode
          gpu_safe_mode="''${UE_GPU_SAFE_MODE:-auto}"
          case "$gpu_safe_mode" in
            auto|on|off|none) ;;
            *) gpu_safe_mode="auto" ;;
          esac
          if [[ "$gpu_safe_mode" == "auto" ]]; then
            if [[ -e /proc/driver/nvidia/version ]] && grep -q "Open Kernel Module" /proc/driver/nvidia/version 2>/dev/null; then
              gpu_safe_mode="on"
            else
              gpu_safe_mode="none"
            fi
          fi
          if [[ "$gpu_safe_mode" == "on" ]]; then
            want_file=1
            cvars_lines+=("r.Shadow.Virtual.Enable=0")
          fi

          if [[ "$want_file" != 1 ]]; then
            return 0
          fi

          local cache_home cvars_dir cvars_file
          cache_home="''${XDG_CACHE_HOME:-''${HOME:-/tmp}/.cache}"
          cvars_dir="$cache_home/unreal-engine/wrapper"
          mkdir -p "$cvars_dir"
          cvars_file="$cvars_dir/wrapper-cvars.ini"

          {
            echo "[Startup]"
            printf '%s\n' "''${cvars_lines[@]}"
          } >"$cvars_file"

          printf '%s\n' "-cvarsini=$cvars_file"
        }

        cleanup_cef_singletons() {
          if [[ -z "''${HOME:-}" ]]; then
            return 0
          fi

          local config_home tmp_dir have_ss cleanup_mode
          config_home="''${XDG_CONFIG_HOME:-$HOME/.config}"
          tmp_dir="''${TMPDIR:-/tmp}"

          have_ss=0
          if command -v ss >/dev/null 2>&1; then
            have_ss=1
          fi

          cleanup_mode="''${UE_CEF_CLEANUP_MODE:-aggressive}"
          case "$cleanup_mode" in
            aggressive|safe|force|none) ;;
            *) cleanup_mode="aggressive" ;;
          esac

          if [[ "$cleanup_mode" == "none" ]]; then
            return 0
          fi

          if [[ "$have_ss" == 1 ]]; then
            shopt -s nullglob
            for dir in "$tmp_dir"/.org.chromium.Chromium.*; do
              [[ -d "$dir" ]] || continue
              if [[ "$cleanup_mode" != "force" ]] && ss -xl 2>/dev/null | grep -F -q "$dir/SingletonSocket"; then
                continue
              fi
              rm -rf "$dir" || true
            done
          fi

          shopt -s nullglob
          for wc in "$config_home"/Epic/UnrealEngine/*/Saved/webcache*; do
            [[ -d "$wc" ]] || continue

            local in_use socket_target socket_dir socket_path has_singleton
            in_use=0
            has_singleton=0

            local -a singleton_files
            singleton_files=("$wc"/Singleton*)
            if (( "''${#singleton_files[@]}" > 0 )); then
              has_singleton=1
            fi

            if [[ -L "$wc/SingletonSocket" ]]; then
              socket_target="$(readlink "$wc/SingletonSocket" || true)"
              if [[ "$socket_target" == "$tmp_dir"/.org.chromium.Chromium.*/* ]]; then
                socket_dir="$(dirname "$socket_target")"
                socket_path="$socket_dir/SingletonSocket"
                if [[ "$have_ss" == 1 ]] && ss -xl 2>/dev/null | grep -F -q "$socket_path"; then
                  in_use=1
                else
                  if [[ "$have_ss" == 1 ]]; then
                    rm -rf "$socket_dir" || true
                  fi
                fi
              fi
            fi
            if [[ -S "$wc/SingletonSocket" ]]; then
              socket_path="$wc/SingletonSocket"
              if [[ "$have_ss" == 1 ]] && ss -xl 2>/dev/null | grep -F -q "$socket_path"; then
                in_use=1
              fi
            fi

            if [[ "$has_singleton" == 1 && ( "$cleanup_mode" == "aggressive" || "$cleanup_mode" == "force" ) ]]; then
              if [[ "$in_use" == 1 && "$cleanup_mode" != "force" ]]; then
                echo "UE CEF cleanup: webcache appears in use; not deleting: $wc" >&2
              else
                echo "UE CEF cleanup: deleting webcache dir due to Singleton* artifacts: $wc" >&2
                rm -rf "$wc" || true
              fi
              continue
            fi

            if [[ "$in_use" == 0 ]]; then
              if (( "''${#singleton_files[@]}" > 0 )); then
                rm -f "''${singleton_files[@]}" || true
              fi
            fi
          done
        }

        UE_SRC="''${UE_SRC:-}"
        if [[ -z "$UE_SRC" ]]; then
          echo "ERROR: UE_SRC is not set." >&2
          echo "Set UE_SRC=/abs/path/to/UnrealEngine in your shell or session variables." >&2
          exit 1
        fi
        if [[ ! -d "$UE_SRC" ]]; then
          echo "ERROR: UE source dir not found: $UE_SRC" >&2
          echo "Set UE_SRC=/abs/path/to/UnrealEngine in your shell or session variables." >&2
          exit 1
        fi
        if [[ ! -x "$UE_SRC/Engine/Binaries/Linux/UnrealEditor" ]]; then
          echo "ERROR: UnrealEditor not found at: $UE_SRC/Engine/Binaries/Linux/UnrealEditor" >&2
          echo "Expected a prepared + built UE tree at UE_SRC." >&2
          echo "Phase 1 commands (inside FHS):" >&2
          echo "  cd \"$UE_SRC\" && ./Setup.sh --force" >&2
          echo "  cd \"$UE_SRC\" && ./GenerateProjectFiles.sh" >&2
          echo "  cd \"$UE_SRC\" && ./Engine/Build/BatchFiles/Linux/Build.sh UnrealEditor Linux Development -Progress" >&2
          echo "  cd \"$UE_SRC\" && ./Engine/Build/BatchFiles/Linux/Build.sh ShaderCompileWorker Linux Development -Progress" >&2
          exit 1
        fi

        maybe_force_sdl_videodriver || true
        mapfile -t UE_EXTRA_ARGS < <(maybe_force_allocator_args "$@" || true)
        mapfile -t UE_VULKAN_PRESENT_ARGS < <(maybe_force_vulkan_present_mode_args "$@" || true)
        mapfile -t UE_CVARS_ARGS < <(maybe_force_cvarsini_args "$@" || true)
        cleanup_cef_singletons || true

        exec ${unrealFhs}/bin/ue5-fhs -c 'ulimit -n 16000 || true; UE_SRC="$1"; shift; cd "$UE_SRC"; exec "$UE_SRC/Engine/Binaries/Linux/UnrealEditor" "$@"' bash "$UE_SRC" "''${UE_EXTRA_ARGS[@]}" "''${UE_VULKAN_PRESENT_ARGS[@]}" "''${UE_CVARS_ARGS[@]}" "$@"
      '';

      localWrapper = pkgs.symlinkJoin {
        name = "unreal-engine-local-wrapper";
        paths = [
          localUnrealEditor
        ];
        postBuild = ''
          mkdir -p "$out/bin"
          ln -s UnrealEditor "$out/bin/ue5editor"
          ln -s ue5editor "$out/bin/ue5"
          ln -s ue5editor "$out/bin/UE5"
          ln -s ue5editor "$out/bin/unreal-engine-5"
          ln -s ue5editor "$out/bin/unreal-engine-5.sh"
        '';
      };

      desktopEntry = pkgs.runCommand "unreal-engine-desktop-entry" { } ''
        mkdir -p "$out/share/applications"
        install -Dm644 ${./com.unrealengine.UE5Editor.desktop} \
          "$out/share/applications/com.unrealengine.UE5Editor.desktop"
        chmod +x "$out/share/applications/com.unrealengine.UE5Editor.desktop"
      '';

      icon = pkgs.runCommand "unreal-engine-icon" { } ''
        mkdir -p "$out/share/pixmaps"
        install -Dm644 ${./ue5editor.svg} "$out/share/pixmaps/ue5editor.svg"
      '';
    in
    pkgs.symlinkJoin {
      name = "unreal-engine-local-wrapper";
      paths = [
        localWrapper
        desktopEntry
        icon
      ];
      meta = packageMeta // {
        mainProgram = "ue5editor";
      };
    };
in
if isLinux then
  linuxPackage
else
  pkgs.runCommand "unreal-unsupported" { meta = packageMeta; } ''
    mkdir -p "$out"
    printf '%s\n' "Unreal is only available on Linux in this repository." > "$out/README"
  ''
