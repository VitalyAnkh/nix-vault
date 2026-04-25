# Standalone Home-Manager Configuration

This NixOS configuration now supports standalone home-manager usage on non-NixOS systems.

## Available Configurations

### Generic Configurations

- `vitalyr@x86_64-linux` - Basic TUI configuration for x86_64 Linux
- `vitalyr-desktop@x86_64-linux` - Full GUI configuration for x86_64 Linux
- `vitalyr@aarch64-linux` - Basic TUI configuration for ARM64 Linux
- `vitalyr-desktop@aarch64-linux` - Full GUI configuration for ARM64 Linux
- `vitalyr@aarch64-darwin` - Configuration for macOS (ARM64)

When a configuration name contains `@`, quote that attr name in flake commands, for example:
`.#homeConfigurations."vitalyr@x86_64-linux".activationPackage`.

### Host-Specific Configurations

- `jojo` - Example low-spec standalone Linux host with a minimal TUI-only setup
- `revachol` - Example non-NixOS Linux host with host-specific GUI setup

## Usage on Non-NixOS Systems

### Prerequisites

1. Install Nix package manager on your system
2. Enable flakes in your Nix configuration

### Installation

1. Clone this repository:

```bash
git clone https://github.com/yourusername/nix-vault.git
cd nix-vault
```

2. Build and activate a configuration:

```bash
# For basic TUI setup
nix build '.#homeConfigurations."vitalyr@x86_64-linux".activationPackage'
./result/activate

# Or for a host-specific GUI setup
nix build .#homeConfigurations.revachol.activationPackage
./result/activate
```

3. Or use home-manager directly (if installed):

```bash
home-manager switch --flake .#revachol
```

## Creating a New Host Configuration

1. Choose the host-home entry location for your platform:

```bash
mkdir -p home/hosts/linux
$EDITOR home/hosts/linux/YOUR_HOST_NAME.nix

# Or on Darwin
mkdir -p home/hosts/darwin
$EDITOR home/hosts/darwin/darwin-YOUR_HOST_NAME.nix
```

2. Put the host-specific Home Manager settings in that file. Shared imports belong in the host-home
   entry file itself:

```nix
# Full Linux desktop host
{ config, ... }:
{
  imports = [ ../../linux/gui.nix ];

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/YOUR_HOST_NAME";
}
```

For minimal standalone TUI-only Linux hosts, import only the base layers instead:

```nix
{ config, ... }:
{
  imports = [
    ../../base/core
    ../../base/tui
  ];

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/YOUR_HOST_NAME";
}
```

For Darwin host-home files, import `../../darwin` instead:

```nix
{ config, ... }:
{
  imports = [ ../../darwin ];

  programs.ssh.matchBlocks."github.com".identityFile =
    "${config.home.homeDirectory}/.ssh/YOUR_HOST_NAME";
}
```

3. Create a new configuration file under the matching outputs tree, for example
   `outputs/x86_64-linux/src/YOUR_HOST_NAME.nix`:

```nix
{
  inputs,
  lib,
  myvars,
  mylib,
  system,
  genSpecialArgs,
  ...
}@args:
let
  name = "YOUR_HOST_NAME";

  home-manager-config = import ./home-manager.nix args;
  inherit (home-manager-config) mkHomeConfig;
in
{
  homeConfigurations = {
    "${name}" = mkHomeConfig {
      modules = [ (mylib.relativeToRoot "home/hosts/linux/${name}.nix") ];
    };
  };
}
```

4. Add files to git and build:

```bash
# Linux example
git add home/hosts/linux/YOUR_HOST_NAME.nix outputs/x86_64-linux/src/YOUR_HOST_NAME.nix
nix build .#homeConfigurations.YOUR_HOST_NAME.activationPackage

# Darwin example
git add home/hosts/darwin/darwin-YOUR_HOST_NAME.nix outputs/aarch64-darwin/src/YOUR_HOST_NAME.nix
nix build .#homeConfigurations.YOUR_HOST_NAME.activationPackage
```

## Architecture

The standalone home-manager support is implemented through:

1. **lib/homeManagerConfiguration.nix** - Core function for building home-manager configurations
2. **outputs/\*/src/home-manager.nix** - Common module definitions per architecture
3. **outputs/\*/src/<hostname>.nix** - Host-specific configurations
4. **home/hosts/linux/<hostname>.nix** / **home/hosts/darwin/darwin-<hostname>.nix** - Host-specific
   home-manager entry modules

This architecture allows:

- Reuse of existing home-manager modules
- Host-specific customization
- Support for multiple architectures
- Coexistence with NixOS configurations

For the current host-home layout and conventions, also see
[`home/hosts/README.md`](../home/hosts/README.md).
