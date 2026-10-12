{
  # NOTE: the args not used in this file CAN NOT be removed!
  # because haumea pass argument lazily,
  # and these arguments are used in the functions like `mylib.nixosSystem`, `mylib.colmenaSystem`, etc.
  inputs,
  lib,
  mylib,
  myvars,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "youko";
  requiredSecretFiles = [
    "certs/ecc-server.key.age"
    "server/cloudflare-dns-api-token.env.age"
    "server/grafana-admin-password.age"
    "server/grafana-secret-key.age"
    "server/k3s-test-1-token.age"
    "server/postgres-playground-password.age"
    "server/restic-rest-htpasswd.age"
    "server/rustfs.env.age"
    "server/sftpgo.env.age"
    "server/transmission-credentials.json.age"
  ];
  privateSecretsAvailable = lib.all (
    relativePath: builtins.pathExists "${inputs.mysecrets}/${relativePath}"
  ) requiredSecretFiles;
  tags = [
    name
    "virt-youko"
  ];
  ssh-user = "root";

  modules = {
    nixos-modules =
      (map mylib.relativeToRoot [
        # common
        "secrets/nixos.nix"
        "modules/nixos/server/server.nix"
        # host specific
        "hosts/12kingdoms-${name}"
      ])
      ++ [
        {
          modules.secrets.preservation.enable = true;
        }
      ];
  };

  systemArgs = modules // args;
in
if !privateSecretsAvailable then
  # The public checkout intentionally points at a placeholder secrets input.
  # Keep the host source available, but do not expose a configuration that
  # would fail evaluation or silently substitute fake credentials.
  { }
else
  {
    nixosConfigurations.${name} = mylib.nixosSystem systemArgs;

    colmena.${name} = mylib.colmenaSystem (
      systemArgs
      // {
        inherit tags ssh-user;
      }
    );

    packages.${name} = inputs.self.nixosConfigurations.${name}.config.system.build.images.iso;
  }
