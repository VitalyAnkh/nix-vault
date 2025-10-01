{
  config,
  pkgs-unstable,
  ...
}:
{
  # make the tailscale command usable to users
  environment.systemPackages = [ pkgs-unstable.tailscale ];

  # enable the tailscale service
  services.tailscale = {
    enable = true;
    # port = 12345;
    # interfaceName = "tailscale0";
    # # allow the Tailscale UDP port through the firewall
    # openFirewall = true;
    # useRoutingFeatures = "client";
    # extraSetFlags = [
    #   "--accept-routes"
    # ];
  };
}
