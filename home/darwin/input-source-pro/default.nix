{ config, lib, ... }:
{
  options.modules.desktop.inputSourcePro.enable =
    lib.mkEnableOption "the repository's Input Source Pro preferences (ABC whenever an app becomes active)";

  # The app itself is the input-source-pro Homebrew cask (hosts/darwin-astra/homebrew.nix);
  # this module only writes its preferences. The app reads them at launch, so restart it
  # after a change.
  config = lib.mkIf config.modules.desktop.inputSourcePro.enable {
    targets.darwin.defaults."com.runjuu.Input-Source-Pro" = {
      # Every app and website starts with ABC; an empty default disables switching.
      systemWideDefaultKeyboardId = "com.apple.keylayout.ABC";
      # Switch to that default instead of restoring an app's last input source, so the
      # app never selects Shuangpin itself: programmatic switches into a Chinese input
      # source are unreliable on macOS. Chinese stays one Control+Shift+8 away.
      isRestorePreviouslyUsedInputSource = false;
      # Enhanced Mode needs Accessibility access, and the CJKV fix replays the
      # "Select the previous input source" shortcut; neither is needed for ABC.
      isDetectSpotlightLikeApp = false;
      isCJKVFixEnabled = false;
      # No global mouse monitor for the long-press indicator.
      isActiveWhenLongpressLeftMouse = false;
      isLaunchAtLogin = true;
    };
  };
}
