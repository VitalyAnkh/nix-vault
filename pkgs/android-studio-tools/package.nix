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
      # Google publishes the Darwin archive on a separate cadence from the
      # Linux archive used by nixpkgs. Keep this pin aligned with the latest
      # macOS archive available in the repository index.
      sourceVersion = "15641748";
    in
    {
      # The macOS archive carries Google's signed Darwin JNI libraries; its scripts
      # already have the Mac heading.
      src = fetchzip {
        name = "source";
        url = "https://dl.google.com/android/repository/commandlinetools-mac-${sourceVersion}_latest.zip";
        hash = "sha256-oiU3ZuEo9tT/WU0jhXtn9SAop+h3OyY03MPT5g0TspA=";
      };

      meta = old.meta // {
        sourceProvenance = with lib.sourceTypes; [
          binaryBytecode
          binaryNativeCode
        ];
      };
    }
  )
