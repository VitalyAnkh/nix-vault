{
  pkgs,
  nur-ryan4yin,
  ...
}:
{
  home.packages = with pkgs; [
    mitmproxy # http/https proxy tool
    insomnia # REST client
    wireshark # network analyzer

    bottom

    xorg.xeyes

    ninja
    uv
    trash-cli

    # IDEs
    jetbrains-toolbox
    # jetbrains.idea-community

    # AI cli tools
    # install gemini-cli with pnpm add -g @google/gemini-cli
    # nur-ryan4yin.packages.${pkgs.system}.gemini-cli
    k8sgpt
    kubectl-ai # an ai helper opensourced by google
  ];
}
