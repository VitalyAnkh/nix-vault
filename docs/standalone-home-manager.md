# Standalone Home-Manager Configuration

This NixOS configuration now supports standalone home-manager usage on non-NixOS systems.

## Available Configurations

### Generic Configurations

- `vitalyr@x86_64-linux` - Basic TUI configuration for x86_64 Linux
- `vitalyr-gui@x86_64-linux` - Full GUI configuration for x86_64 Linux
- `vitalyr@aarch64-linux` - Basic TUI configuration for ARM64 Linux
- `vitalyr-gui@aarch64-linux` - Full GUI configuration for ARM64 Linux
- `vitalyr@aarch64-darwin` - Configuration for macOS (ARM64)

### Host-Specific Configurations

- `revachol` - Example non-NixOS host with basic TUI setup
- `revachol-gui` - Example non-NixOS host with full desktop environment

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
nix build .#homeConfigurations.revachol.activationPackage
./result/activate

# Or for GUI desktop setup
nix build .#homeConfigurations.revachol-gui.activationPackage
./result/activate
```

3. Or use home-manager directly (if installed):

```bash
home-manager switch --flake .#revachol
```

## Creating a New Host Configuration

1. Create a new host directory:

```bash
mkdir -p hosts/YOUR_HOST_NAME
```

2. Create `hosts/YOUR_HOST_NAME/home.nix` with host-specific settings:

```nix
{ config, pkgs, lib, ... }:
{
  # Your host-specific configuration
  programs.git.enable = true;
  # ...
}
```

3. Create a new configuration file in `outputs/x86_64-linux/src/YOUR_HOST_NAME.nix`:

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

  # Import common configurations
  home-manager-config = import ./home-manager.nix args;
  inherit (home-manager-config) base-home-modules gui-home-modules mkHomeConfig;

  # Define your modules
  base-modules = {
    home-modules = base-home-modules ++ [
      (mylib.relativeToRoot "hosts/${name}/home.nix")
    ];
  };
in
{
  homeConfigurations = {
    "${name}" = mkHomeConfig {
      modules = base-modules.home-modules;
    };
  };
}
```

4. Add files to git and build:

```bash
git add hosts/YOUR_HOST_NAME outputs/x86_64-linux/src/YOUR_HOST_NAME.nix
nix build .#homeConfigurations.YOUR_HOST_NAME.activationPackage
```

## Architecture

The standalone home-manager support is implemented through:

1. **lib/homeManagerConfiguration.nix** - Core function for building home-manager configurations
2. **outputs/\*/src/home-manager.nix** - Common module definitions per architecture
3. **outputs/\*/src/<hostname>.nix** - Host-specific configurations
4. **hosts/<hostname>/home.nix** - Host-specific home-manager settings

This architecture allows:

- Reuse of existing home-manager modules
- Host-specific customization
- Support for multiple architectures
- Coexistence with NixOS configurations
