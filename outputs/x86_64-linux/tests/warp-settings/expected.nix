let
  host = {
    enable = true;
    settings = {
      appearance.text.font_name = "Maple Mono NF CN";
      global_hotkey.toggle_all_windows = {
        enabled = true;
        keybinding = "ctrl-shift-E";
      };
    };
    settingsFile = "/.config/warp-oss/settings.toml";
    preserved = true;
    managesMutableConfig = false;
    syncAfterWriteBoundary = true;
    syncFailureIsWarning = true;
    warpInstalled = true;
    fontInstalled = true;
  };
in
{
  eva = host;
  muon = host;
}
