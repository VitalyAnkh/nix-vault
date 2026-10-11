{
  lib,
  stdenv,
  fetchzip,
  android-studio-tools,
}:
if !stdenv.hostPlatform.isDarwin then
  android-studio-tools
else
  android-studio-tools.overrideAttrs (
    old:
    let
      sourceVersion = "14742923";
    in
    assert lib.assertMsg (old.version == sourceVersion)
      "android-studio-tools: upstream version changed; update the macOS archive hash or remove the Darwin workaround.";
    {
      # The macOS archive carries Google's signed Darwin JNI libraries; its scripts
      # already have the Mac heading.
      src = fetchzip {
        name = "source";
        url = "https://dl.google.com/android/repository/commandlinetools-mac-${sourceVersion}_latest.zip";
        hash = "sha256-pY6nRtT7coqIShy5AmAh2z4cGD4Gtat3GclNj5oMR1g=";
      };

      meta = old.meta // {
        sourceProvenance = with lib.sourceTypes; [
          binaryBytecode
          binaryNativeCode
        ];
      };
    }
  )
