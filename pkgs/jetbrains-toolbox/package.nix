{
  stdenv,
  fetchurl,
  jetbrains-toolbox,
}:
if !stdenv.hostPlatform.isDarwin then
  jetbrains-toolbox
else
  jetbrains-toolbox.overrideAttrs (
    finalAttrs: _: {
      # Keep this on the newest release listed by
      # https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release.
      version = "3.8.1.88030";
      # nixpkgs downloads from download-cdn.jetbrains.com, which answers 404 from
      # some regions; download.jetbrains.com redirects to the regional CDN.
      src = fetchurl {
        url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${finalAttrs.version}-arm64.dmg";
        hash = "sha256-Lwe3gWiRNHbNrk6hwfp0uwdaS8twxZioXeCZeFpunHM=";
      };
    }
  )
