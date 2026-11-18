{
  stdenv,
  fetchurl,
  fetchzip,
  jetbrains-toolbox,
}:
let
  # nixpkgs downloads from download-cdn.jetbrains.com, which answers 404 from
  # some regions; download.jetbrains.com redirects to the regional CDN.
  regionalUrl =
    builtins.replaceStrings
      [ "https://download-cdn.jetbrains.com/" ]
      [ "https://download.jetbrains.com/" ];
in
if !stdenv.hostPlatform.isDarwin then
  # Same archive and hash as nixpkgs, so the package keeps nixpkgs' store paths.
  jetbrains-toolbox.override {
    fetchzip = args: fetchzip (args // { url = regionalUrl args.url; });
  }
else
  jetbrains-toolbox.overrideAttrs (
    finalAttrs: _: {
      # Keep this on the newest release listed by
      # https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release.
      version = "3.9.1.89198";
      src = fetchurl {
        url = "https://download.jetbrains.com/toolbox/jetbrains-toolbox-${finalAttrs.version}-arm64.dmg";
        hash = "sha256-vU7XgWa7m6q50hGwCkn8hlwYen7wKyggB/BNiJpj+m0=";
      };
    }
  )
