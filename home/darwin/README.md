# Home Manager's Darwin Submodules

This directory contains macOS-specific Home Manager configurations for Darwin systems.

## Configuration Modules

### Core Configurations

- **default.nix**: Entry point that imports all Darwin configurations
- **shell.nix**: Shell configurations and environment settings
- **terminal.nix**: Sets a 15px font size across Alacritty, Ghostty, and Kitty
- **rime-squirrel.nix**: [Rime Squirrel](https://github.com/rime/squirrel) input method
  configuration

### Keyboard

- **karabiner/**: Opt-in (`modules.desktop.karabiner.enable`)
  [Karabiner-Elements](https://karabiner-elements.pqrs.org/) rules: Linux-style Ctrl shortcuts in
  selected GUI apps, a Caps Lock/left Control swap on every keyboard, a Command/Option swap on the
  built-in keyboard, and a Ctrl+Shift+Q Emacs toggle; see
  [karabiner/README.md](./karabiner/README.md)
- **input-source-pro/**: Opt-in (`modules.desktop.inputSourcePro.enable`) preferences for
  [Input Source Pro](https://inputsource.pro/), which selects ABC whenever an app becomes active;
  the app itself comes from a Homebrew cask

### Network Configuration

- **proxy/**: Network proxy configurations
  - `proxychains.conf`: Proxy chains configuration for network routing
  - Proxy settings for development tools and applications

## Features

- macOS-specific package installations and configurations
- Native macOS applications and utilities
- Touch ID and system integration
- Homebrew integration for additional packages
- macOS-specific shell configurations and aliases
