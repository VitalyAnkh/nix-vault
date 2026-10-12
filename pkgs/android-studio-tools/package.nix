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
      # Linux and macOS archives share build numbers; keep this on the newest
      # build in https://dl.google.com/android/repository/repository2-3.xml.
      # Since cmdline-tools 22.0 the macOS archives are per architecture (the
      # unsuffixed commandlinetools-mac name stops at 15641748).
      version = "16111833";
      arch =
        {
          aarch64 = "arm64";
          x86_64 = "x86_64";
        }
        .${stdenv.hostPlatform.parsed.cpu.name};
      hashes = {
        arm64 = "sha256-+JN101vIjhAsrPKasK8xe29aBOA7hUL/QDSKe9TJnNg=";
        x86_64 = "sha256-cRsJBCbrme55F62oVHXTdxFwGa3wz08e6awIDgz2eQQ=";
      };
    in
    {
      inherit version;
      # The macOS archive carries Google's signed Darwin JNI libraries and, since
      # cmdline-tools 23.0, the native `android` CLI that sdkmanager forwards to.
      # Its scripts already have the Mac heading.
      src = fetchzip {
        name = "source";
        url = "https://dl.google.com/android/repository/commandlinetools-mac_${arch}-${version}_latest.zip";
        hash = hashes.${arch};
      };

      meta = old.meta // {
        sourceProvenance = with lib.sourceTypes; [
          binaryBytecode
          binaryNativeCode
        ];
      };
    }
  )
