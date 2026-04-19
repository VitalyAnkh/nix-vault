{ pkgs, ... }:
{
  home.packages = with pkgs; [
    android-tools

    # S3 client
    rclone-ui
  ];
}
