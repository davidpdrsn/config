# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal configuration repository for a macOS development environment managed with nix-darwin and home-manager. The setup includes dotfiles for Neovim, Zsh, Tmux, Git, and various system configurations.

## Development Commands

### System Management
- `darwin-rebuild switch --flake .` - Apply system-wide configuration changes
- `darwin-rebuild build --flake .` - Build configuration without applying

Don't run `home-manager switch --flake .`. Use `darwin-rebuild switch --flake .` instead.

### Configuration Editing
- Configuration files are organized by tool in subdirectories
- After editing configs, run the appropriate rebuild command above
- System configs are in `configuration.nix` and `flake.nix`
- User configs are in `home.nix` and tool-specific directories

### Neovim Development
- Neovim config is in `nvim/` directory with Lua configuration
- `<leader>o` (in Lua files) - Source current file for testing
- Uses lazy.nvim plugin manager with plugins in `nvim/lua/plugins/`
- Custom functions in `nvim/lua/common.lua` for formatting and tmux integration

## Architecture

### Nix Configuration Structure
- `flake.nix`: Main entry point defining inputs and system configuration
- `configuration.nix`: System-wide macOS settings via nix-darwin
- `home.nix`: User environment managed by home-manager
- Personal dev tools are loaded as flake inputs from GitHub repositories

### Neovim Configuration
- `nvim/init.lua`: Main configuration entry point
- `nvim/lua/common.lua`: Shared utilities for formatting, tmux integration
- `nvim/lua/plugins/`: Plugin configurations using lazy.nvim
- Language-specific formatting commands for Rust, Go, C#, TypeScript, Nix, and Lua
- Custom tmux integration for running commands in terminal panes

### Development Tools Integration
- Git configuration with delta diff viewer and LFS support
- Ripgrep with custom exclusions for common build artifacts
- Custom personal CLI tools loaded from private repositories
- Tmux integration for running commands from Neovim

### System Customizations
- macOS system defaults configured for development workflow
- Homebrew casks for GUI applications
- Custom keybindings and window management settings
- Touch ID enabled for sudo authentication

## Key Features

- Automated system and user environment management with Nix
- Integrated development workflow between Neovim and tmux
- Custom formatting commands per language with `<space>lf`
- File path copying and visual selection utilities in Neovim
- Personal CLI tools for git workflow management
