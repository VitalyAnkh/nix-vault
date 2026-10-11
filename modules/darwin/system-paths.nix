{ pkgs, ... }:
let
  # Like macOS's path_helper, add the directories listed in /etc/paths and
  # /etc/paths.d, but after the existing PATH rather than in front of it.
  appendSystemPaths = pkgs.writeShellScript "append-system-paths" ''
    path=$1
    for file in /etc/paths /etc/paths.d/*; do
      [ -f "$file" ] || continue
      while IFS= read -r dir || [ -n "$dir" ]; do
        case "$dir" in
          "" | *:*) continue ;;
        esac
        case ":$path:" in
          *":$dir:"*) ;;
          *) path=''${path:+$path:}$dir ;;
        esac
      done <"$file"
    done
    printf '%s\n' "$path"
  '';
in
{
  # set-environment replaces PATH, and nix-darwin's /etc/zprofile does not run
  # path_helper, so Zsh and Bash would otherwise lose these directories. Keep this a
  # single command substitution: babelfish translates it for Fish as well.
  environment.extraInit = ''
    export PATH="$(${appendSystemPaths} "$PATH")"
  '';
}
