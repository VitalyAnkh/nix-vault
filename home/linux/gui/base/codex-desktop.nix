{
  config,
  lib,
  pkgs,
  ...
}:
with lib;
let
  cfg = config.modules.desktop.codexDesktop;
  extensionUuid = "codex-window-control@openai.com";
  extensionSource = "${pkgs.codex-desktop}/share/gnome-shell/extensions/${extensionUuid}";
  extensionTarget = "${config.home.homeDirectory}/.local/share/gnome-shell/extensions/${extensionUuid}";
  settingsDir = "${config.home.homeDirectory}/.config/codex-desktop";
  settingsFile = "${config.home.homeDirectory}/.config/codex-desktop/settings.json";
in
{
  options.modules.desktop.codexDesktop = {
    enable = mkEnableOption "Codex Desktop";
    computerUse.enable = mkEnableOption "Linux Computer Use support";
  };

  config = mkMerge [
    {
      modules.desktop.codexDesktop.enable = mkDefault pkgs.stdenv.isx86_64;
      modules.desktop.codexDesktop.computerUse.enable = mkDefault true;
    }

    (mkIf cfg.enable (mkMerge [
      {
        home.packages = [ pkgs.codex-desktop ];
      }

      (mkIf cfg.computerUse.enable {
        modules.desktop.ydotoold.enable = mkDefault true;
        home.activation.installCodexWindowControlExtension = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          target="${extensionTarget}"
          if [ -L "$target" ]; then
            run rm "$target"
          fi
          if [ -e "$target" ] && [ ! -d "$target" ]; then
            run rm -f "$target"
          fi
          run mkdir -p "$target"
          for file in metadata.json extension.js; do
            if [ -e "$target/$file" ] || [ -L "$target/$file" ]; then
              run rm -f "$target/$file"
            fi
            run ${pkgs.coreutils}/bin/install -m 0644 -T "${extensionSource}/$file" "$target/$file"
          done
        '';
        home.activation.enableCodexWindowControlExtension =
          lib.hm.dag.entryAfter [ "installCodexWindowControlExtension" ]
            ''
              dconf_run() {
                if [ -n "''${DBUS_SESSION_BUS_ADDRESS-}" ]; then
                  "$@" && return 0
                fi
                ${pkgs.dbus}/bin/dbus-run-session \
                  --dbus-daemon=${pkgs.dbus}/bin/dbus-daemon \
                  -- "$@"
              }

              next=""
              current="$(
                dconf_run ${pkgs.dconf}/bin/dconf read /org/gnome/shell/enabled-extensions 2>/dev/null || true
              )"

              if [ -z "$current" ] || [ "$current" = "[]" ] || [ "$current" = "@as []" ]; then
                next="['${extensionUuid}']"
              elif ! printf '%s' "$current" | ${pkgs.gnugrep}/bin/grep -Fq "'${extensionUuid}'"; then
                next="$(printf '%s' "$current" | ${pkgs.gnused}/bin/sed "s/]$/, '${extensionUuid}']/")"
              fi

              if [ -n "''${next-}" ]; then
                run dconf_run ${pkgs.dconf}/bin/dconf write /org/gnome/shell/enabled-extensions "$next"
              fi
            '';
        home.activation.mergeCodexDesktopSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p "${settingsDir}"
          if [ -e "${settingsFile}" ]; then
            current="$(${pkgs.coreutils}/bin/cat "${settingsFile}")"
          else
            current='{}'
          fi
          if ! current="$(
            printf '%s\n' "$current" \
              | ${pkgs.jq}/bin/jq -c 'if type == "object" then . else {} end' 2>/dev/null
          )"; then
            current='{}'
          fi
          run ${pkgs.bash}/bin/bash -e -u -o pipefail -c '
            tmp="$2"
            rm -f "$tmp"
            if printf "%s\n" "$1" | ${pkgs.jq}/bin/jq '"'"'.["codex-linux-computer-use-ui-enabled"] = true'"'"' > "$tmp"; then
              mv "$tmp" "$3"
            else
              rm -f "$tmp"
              exit 1
            fi
          ' _ "$current" "${settingsFile}.tmp" "${settingsFile}"
        '';
      })
    ]))
  ];
}
