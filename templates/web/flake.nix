{
  description = "Web development environment template";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
  };

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];
      toolingManifest = builtins.fromJSON (builtins.readFile ./tooling/package.json);
      viteVersion = toolingManifest.dependencies.vite;
      createViteVersion = toolingManifest.dependencies."create-vite";
      forAllSystems = nixpkgs.lib.genAttrs systems;
      mkPkgs =
        system:
        import nixpkgs {
          inherit system;
        };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          webTooling = pkgs.buildNpmPackage {
            pname = "web-template-tooling";
            version = "0.0.0";
            src = ./tooling;
            nodejs = pkgs.nodejs_22;
            npmDepsHash = "sha256-6PujY6L+c+mBy0/UGA1G1UZLTfr3EGfMnzs9CIGy4r0=";
            dontNpmBuild = true;
            dontNpmPrune = true;
            nativeBuildInputs = [ pkgs.makeWrapper ];

            installPhase = ''
              runHook preInstall

              node="${pkgs.nodejs_22}/bin/node"
              packageOut="$out/lib/node_modules/web-template-tooling"
              mkdir -p "$packageOut" "$out/bin"

              cp package.json package-lock.json "$packageOut"/
              cp -r node_modules "$packageOut"/

              wrapCli() {
                local name="$1"
                local script="$2"

                makeWrapper "$node" "$out/bin/$name" \
                  --add-flags "$packageOut/$script"
              }

              wrapCli vite "node_modules/vite/bin/vite.js"
              wrapCli create-vite "node_modules/create-vite/index.js"
              wrapCli cva "node_modules/create-vite/index.js"

              runHook postInstall
            '';
          };
        }
      );

      devShells = forAllSystems (
        system:
        let
          pkgs = mkPkgs system;
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              nodejs_22
              pnpm
              yarn
              bun
              biome
              tailwindcss
              tailwindcss-language-server
              self.packages.${system}.webTooling
              nodePackages_latest.eslint
              nodePackages_latest.prettier
              nodePackages_latest.typescript
              nodePackages_latest.typescript-language-server
              nodePackages_latest.vscode-langservers-extracted
              nodePackages_latest.npm-check-updates
            ];

            shellHook = ''
              export npm_config_update_notifier=false
              export npm_config_fund=false
              export COREPACK_ENABLE_AUTO_PIN=0
              export BROWSER=none

              echo "Web dev shell ready: node $(node --version), pnpm $(pnpm --version), bun $(bun --version)"
              echo "Pinned tooling ready: vite ${viteVersion}, create-vite ${createViteVersion}"
            '';
          };
        }
      );
    };
}
