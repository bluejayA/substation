# Installation Guide

This guide covers all the ways to install Substation on your system. Choose the method that works best for your environment.

## Prerequisites

Before installing Substation, ensure you have:

- **Operating System**: macOS 13+ or Linux (Windows users: use WSL2)
- **Terminal**: Any terminal emulator with ncurses support
- **OpenStack Access**: Valid credentials for an OpenStack cloud (Queens or later)
- **Memory**: 200MB+ available (plus 100MB cache for 10K resources)
- **ncurses**: Required library (usually pre-installed on macOS/Linux)

## Installation Methods

### Option 1: Using Docker (Easiest)

The fastest way to get started is using Docker. This method requires no local installation and works identically across all platforms.

```bash
# Run with your OpenStack credentials
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive \
           --tty \
           --env TERM \
           --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

**Important Notes:**

- Your `clouds.yaml` must exist at `~/.config/openstack/clouds.yaml`
- The `--env TERM` passes your terminal type for proper rendering
- The `--rm` flag removes the container after exit (keeps things clean)
- The container includes all dependencies pre-installed

**Verify Installation:**

The application will launch immediately. Press `?` for help or `q` to quit.

### Option 2: Pre-built Binaries

Pre-built binaries are available for macOS and Linux. This is the recommended method for regular use.

#### macOS Installation

```bash
# Download the latest release
# Be sure to be using the latest tagged release
# https://github.com/cloudnull/substation/releases/latest
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation

# Make executable
chmod +x substation

# Move to your PATH
sudo mv substation /usr/local/bin/
```

#### Linux Installation

```bash
# Install ncurses if not present (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y libncurses6

# For RHEL/CentOS/Fedora
# sudo dnf install -y ncurses-libs

# Download the latest release
# Be sure to be using the latest tagged release
# https://github.com/cloudnull/substation/releases/latest
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation

# Make executable
chmod +x substation

# Move to your PATH
sudo mv substation /usr/local/bin/
```

**Verify Installation:**

```bash
# Check substation help
substation --help
```

### Option 3: Building from Source

Building from source gives you the latest features and allows customization. This method requires Swift 6.1 or later.

#### Step 1: Install Swift 6.1

**macOS:**

```bash
# Using Swiftly (recommended)
curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash

# Install 6.1 Swift version
swiftly install "6.1"
swiftly use "6.1"

# Verify Swift version
~/.swiftly/bin/swift --version
# Should show: Swift version 6.1 or later
```

**Linux (Ubuntu/Debian):**

```bash
# Install dependencies
sudo apt-get update
sudo apt-get install -y \
    binutils \
    git \
    gnupg2 \
    libncurses-dev \
    build-essential \
    libc6-dev

# Install Swiftly
curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash

# Install and activate Swift 6.1
swiftly install "6.1"
swiftly use "6.1"

# Verify Swift version
~/.swiftly/bin/swift --version
```

**Linux (RHEL/CentOS/Fedora):**

```bash
# Install dependencies
sudo dnf install -y \
    binutils \
    git \
    gnupg2 \
    ncurses-devel \
    gcc \
    gcc-c++ \
    glibc-devel

# Install Swiftly
curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash

# Install and activate Swift 6.1
swiftly install "6.1"
swiftly use "6.1"

# Verify Swift version
~/.swiftly/bin/swift --version
```

#### Step 2: Clone and Build

```bash
# Clone the repository
git clone https://github.com/cloudnull/substation.git
cd substation

# Build in release mode (optimized)
~/.swiftly/bin/swift build -c release

# The binary will be at:
# .build/release/substation

# Optionally, install to PATH
sudo cp .build/release/substation /usr/local/bin/
```

**Build Options:**

```bash
# Debug build (includes debug symbols, slower)
~/.swiftly/bin/swift build

# Clean build (remove all build artifacts)
~/.swiftly/bin/swift package clean

# Run without installing
~/.swiftly/bin/swift run substation --cloud mycloud
```

**Build Time** (on modern hardware):

- macOS (M-series): ~30 seconds clean build
- Linux (recent CPU): ~45 seconds clean build
- Incremental builds: 1-5 seconds

## Verifying Your Installation

After installation via any method, verify Substation is working:

```bash
# Test with help flag
substation --help

# Expected output should include:
# Usage: substation [options]
# Options:
#   --cloud <name>    Specify cloud from clouds.yaml
#   --wiretap         Enable detailed API logging
#   --help            Show this help message
```

## Next Steps

Now that Substation is installed, you need to configure it:

- **[Configuration Guide](../configuration/index.md)** - Set up your clouds.yaml file
- **[Quick Start Guide](../quick-start.md)** - Get up and running in 1 minute
- **[Getting Started](../getting-started/index.md)** - Learn the basics

## Troubleshooting Installation

### Docker Installation Issues

**Problem**: Container fails to start

**Solution**:

```bash
# Check Docker is running
docker ps

# Verify clouds.yaml exists
ls -l ~/.config/openstack/clouds.yaml

# Try without volume mount first (will fail auth, but confirms container works)
docker run --interactive --tty --rm ghcr.io/cloudnull/substation/substation:latest --help
```

### Binary Installation Issues

**Problem**: "Permission denied" when running substation

**Solution**:

```bash
# Make the binary executable
chmod +x /usr/local/bin/substation

# Verify ownership
ls -l /usr/local/bin/substation
```

**Problem**: "libncurses.so.6: cannot open shared object file" (Linux)

**Solution**:

```bash
# Ubuntu/Debian
sudo apt-get install -y libncurses6

# RHEL/CentOS/Fedora
sudo dnf install -y ncurses-libs
```

### Source Build Issues

**Problem**: "Swift version 6.1 or later is required"

**Solution**:

```bash
# Verify Swift version
~/.swiftly/bin/swift --version

# If wrong version, install/update Swift
swiftly install latest
swiftly use 6.1
```

**Problem**: Build fails with "cannot find libncurses"

**Solution**:

```bash
# Ubuntu/Debian
sudo apt-get install -y libncurses-dev

# RHEL/CentOS/Fedora
sudo dnf install -y ncurses-devel

# macOS (should be pre-installed, but if missing)
brew install ncurses
```

**Problem**: Build warnings or errors

**Solution**:

Substation enforces a **zero-warning build standard**. All warnings must be fixed before the build will succeed. If you encounter build warnings:

1. Ensure you're using Swift 6.1 or later
2. Clean and rebuild:

   ```bash
   ~/.swiftly/bin/swift package clean
   ~/.swiftly/bin/swift build -c release
   ```

3. Check the build log for specific issues
4. Report persistent issues on GitHub

## Getting Help

- **Built-in Help**: Run `substation --help`
- **Documentation**: Complete guides at [Quick Start](../quick-start.md)
- **GitHub Issues**: [Report installation problems](https://github.com/cloudnull/substation/issues)
- **FAQ**: [Common installation questions](../reference/faq.md)
