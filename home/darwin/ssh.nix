{
  config,
  lib,
  myvars,
  ...
}:
{
  config = lib.mkIf config.modules.ssh.personalConfig.enable {
    programs.ssh.extraConfig = myvars.networking.ssh.extraConfig;
  };
}
