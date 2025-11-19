# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

napcat.nix is a Nix flake that packages NapCat (a modern protocol-side framework based on NTQQ) with Linux QQ. It is forked from chronocat.nix and provides a sandboxed environment to run NapCat on NixOS and other Linux systems with Nix.

## Key Architecture

### Modular Structure

The project consists of several interconnected Nix modules:

1. **flake.nix**: Entry point that exposes `lib.buildNapcat` function and `packages.default`
   - Takes a configuration module with `qq_config_dir` and `nc_config_dir` paths
   - Returns a package with a launch script

2. **src/default.nix**: Thin wrapper that imports the sandbox module

3. **src/sources.nix**: Auto-generated file containing version info and download URLs
   - NapCat version, URL, and hash
   - QQ versions for both amd64 and arm64 architectures
   - **Never edit manually** - use `update.sh` instead

4. **src/napcat.nix**: Core package builder
   - Fetches NapCat Shell zip and QQ .deb packages
   - Creates `patched` attribute: QQ package with NapCat integration
   - Patches QQ's package.json to load NapCat via `loadNapCat.js`
   - Supports both x86_64-linux and aarch64-linux

5. **src/sandbox.nix**: Sandboxed launcher using bubblewrap
   - Creates isolated environment with minimal bindings
   - Runs Xvfb (virtual framebuffer) for headless operation
   - Uses runit's runsvdir for service management
   - Manages two services: xvfb and the QQ/NapCat program

### Configuration Directory Layout

The application uses two configuration directories:
- `qq_config_dir`: QQ's configuration (default: `/root/napcat/config`)
- `nc_config_dir`: NapCat's configuration (default: `/root/.config/QQ`)

These are bind-mounted into the sandbox at runtime.

## Common Commands

### Building and Running

```bash
# Quick run with default configuration
nix run

# Build the package
nix build

# Build with flakes explicitly enabled (if not in nix.conf)
nix build --extra-experimental-features flakes

# Run from GitHub directly
nix run github:initialencounter/napcat.nix
```

### Updating Dependencies

```bash
# Update NapCat to latest release
./update.sh napcat

# Update QQ to specific version (provide download URL)
./update.sh qq <QQ_DOWNLOAD_URL>

# Example QQ update:
./update.sh qq https://dldir1v6.qq.com/qqfile/qq/QQNT/a5fab4ff/linuxqq_3.2.18-36580_amd64.deb

# Update flake inputs
nix flake update
```

The `update.sh` script:
- Fetches latest versions from GitHub/QQ servers
- Downloads and computes nix hashes using `nix-prefetch-url`
- Updates `src/sources.nix` with new versions and hashes
- Automatically updates the "Last updated" timestamp

### Development

```bash
# Enter development shell
nix develop
```

## Version Management

Versions are tracked in `src/sources.nix` and automatically updated:
- **Automated updates**: GitHub Actions workflow runs daily (cron: `0 12 * * *`) to check for new NapCat releases
- **Manual updates**: Use `update.sh` script for both NapCat and QQ
- **Commit format**: Updates create commits like "napcat 4.9.70 -> 4.9.71"

## Sandboxing Implementation

The sandbox uses bubblewrap with:
- Unshared namespaces (PID, network shared)
- Read-only Nix store binding
- Timezone set to Asia/Shanghai
- Minimal /proc, /dev, and /tmp mounts
- Services managed via runit (runsvdir)
- Virtual X server (Xvfb) on DISPLAY :114

## Testing Changes

After modifying Nix files, test by:
1. Running `nix build` to ensure the package builds
2. Running `nix run` to verify the application launches
3. Checking that configuration directories are correctly bind-mounted
4. Verifying NapCat integration in the QQ package structure
