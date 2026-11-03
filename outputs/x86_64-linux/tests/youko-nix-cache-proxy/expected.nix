{ outputs, ... }:
# youko needs the private secrets input; skip it when it is absent.
if outputs.nixosConfigurations ? youko then
  {
    nginxEnabled = true;
    caddyVhostExists = true;
    ustcRemainsFirst = true;
    nixosProxyConfigured = true;
    numtideProxyConfigured = true;
    numtideDirectFallback = true;
    cacheLivesOnDataVolume = true;
    nixosUpstream = "https://cache.nixos.org/";
    numtideUpstream = "https://cache.numtide.com/";
  }
else
  { }
