# Getting Started with Substation

Welcome to Substation! This guide will help you get up and running with the OpenStack Terminal UI quickly and efficiently.

## Overview

Substation provides a powerful terminal-based interface for managing OpenStack infrastructure. Whether you're managing a small development cloud or a large production environment, Substation streamlines your operational workflows.

![Substation Dashboard](../assets/substation-dash.png)

## Prerequisites

Before installing Substation, ensure you have:

- **Operating System**: macOS 13+ or Linux (Windows users: use WSL2)
- **Swift**: Version 6.1 or later (strict concurrency required)
- **Terminal**: Any terminal emulator with ncurses support
- **OpenStack Access**: Valid credentials for an OpenStack cloud (Queens or later)
- **Memory**: 200MB+ available (plus 100MB cache for 10K resources)
- **ncurses**: Required library (usually pre-installed on macOS/Linux)

## Installation

### Option 1: Using Docker (Easiest)

The fastest way to get started is using Docker:

```bash
# Run with your OpenStack credentials
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive \
           --tty \
           --env TERM \
           --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

**Notes:**

- Your `clouds.yaml` must exist at `~/.config/openstack/clouds.yaml`
- The `--env TERM` passes your terminal type for proper rendering
- The `--rm` flag removes the container after exit (keeps things clean)

### Option 2: Pre-built Binaries

Pre-built binaries are available for macOS and Linux:

#### `macOS` Installation

```bash
# Be sure to be using the latest tagged release
# https://github.com/cloudnull/substation/releases/latest
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation

# Make executable
chmod +x substation

# Move to your PATH
sudo mv substation /usr/local/bin/

# Verify installation
substation --version
```

#### Linux Installation

```bash
# Install ncurses if not present (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install -y libncurses6

# Be sure to be using the latest tagged release
# https://github.com/cloudnull/substation/releases/latest
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation

# Make executable
chmod +x substation

# Move to your PATH
sudo mv substation /usr/local/bin/

# Verify installation
substation --version
```

### Option 3: Building from Source

Building from source gives you the latest features and allows customization.

#### Step 1: Install Swift 6.1

**macOS:**

```bash
# Using Swiftly (recommended)
curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash
swiftly install latest

# Verify Swift version
~/.swiftly/bin/swift --version
# Should show: Swift version 6.1 or later
```

**Linux:**

```bash
# Install dependencies (Ubuntu/Debian)
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
swiftly install latest
swiftly use 6.1

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

# Verify installation
substation --version
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

## Configuration

### Understanding clouds.yaml

Substation uses the same `clouds.yaml` format as the official Python OpenStack CLI. If you already use OpenStack CLI tools, your existing configuration will work.

**Configuration File Locations** (checked in order):

1. `./clouds.yaml` (current directory - highest priority)
2. `~/.config/openstack/clouds.yaml` (user config - recommended)
3. `/etc/openstack/clouds.yaml` (system-wide config)

### Basic Configuration

Create `~/.config/openstack/clouds.yaml`:

```bash
# Create directory if it doesn't exist
mkdir -p ~/.config/openstack

# Create the file
touch ~/.config/openstack/clouds.yaml

# Set appropriate permissions (important for security!)
chmod 600 ~/.config/openstack/clouds.yaml
```

**Basic Password Authentication:**

```yaml
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: your-username
      password: your-password
      project_name: your-project
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne
```

### Advanced Configuration Options

#### Application Credentials (Recommended)

Application credentials are more secure than passwords and can be scoped to specific projects:

```yaml
clouds:
  production:
    auth:
      auth_url: https://openstack.example.com:5000/v3
      application_credential_id: "abc123..."
      application_credential_secret: "secret456..."
    region_name: RegionOne
```

**Creating Application Credentials:**

```bash
# Using OpenStack CLI
openstack application credential create substation \
    --description "Substation TUI access" \
    --expiration "2026-12-31T23:59:59"

# Save the ID and secret to clouds.yaml
```

#### Multiple Clouds

Manage multiple OpenStack environments:

```yaml
clouds:
  production:
    auth:
      auth_url: https://prod.example.com:5000/v3
      username: prod-operator
      password: prod-password
      project_name: production-ops
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne

  staging:
    auth:
      auth_url: https://staging.example.com:5000/v3
      username: staging-operator
      password: staging-password
      project_name: staging-ops
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne

  development:
    auth:
      auth_url: https://dev.example.com:5000/v3
      application_credential_id: "dev-cred-id"
      application_credential_secret: "dev-cred-secret"
    region_name: RegionOne
```

**Switching Between Clouds:**

```bash
# Specify cloud at runtime
substation --cloud production
substation --cloud staging
substation --cloud development

# Or use environment variable
export OS_CLOUD=production
substation
```

#### Enhanced Configuration

For advanced users, Substation supports extended configuration options:

```yaml
clouds:
  production:
    auth:
      auth_url: https://openstack.example.com:5000/v3
      username: operator
      password: secret
      project_name: operations
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne

    # Performance tuning (optional)
    cache:
      enabled: true
      ttl:
        servers: 120          # 2 minutes (highly dynamic)
        networks: 300         # 5 minutes (moderately stable)
        images: 900           # 15 minutes (rarely change)
        flavors: 900          # 15 minutes (basically static)

    # API configuration (optional)
    interface: public         # public, internal, or admin
    verify: true              # SSL certificate verification
    cacert: /path/to/ca.pem   # Custom CA certificate
```

### Environment Variables

Alternatively, use environment variables (compatible with OpenStack CLI):

```bash
# Authentication
export OS_AUTH_URL=https://openstack.example.com:5000/v3
export OS_USERNAME=operator
export OS_PASSWORD=secret
export OS_PROJECT_NAME=operations
export OS_PROJECT_DOMAIN_NAME=default
export OS_USER_DOMAIN_NAME=default
export OS_REGION_NAME=RegionOne

# Run Substation
substation
```

**Application Credential Variables:**

```bash
export OS_AUTH_URL=https://openstack.example.com:5000/v3
export OS_APPLICATION_CREDENTIAL_ID=abc123...
export OS_APPLICATION_CREDENTIAL_SECRET=secret456...
export OS_REGION_NAME=RegionOne

substation
```

### Testing Your Configuration

**Test Connection:**

```bash
# Test with a specific cloud
substation --cloud mycloud

# Test with environment variables
export OS_CLOUD=mycloud
substation

# Enable debug output for troubleshooting
substation --cloud mycloud --wiretap
```

**Wiretap Mode** (for debugging):

```bash
# Enable detailed API logging
substation --cloud mycloud --wiretap

# Logs written to ~/substation.log
tail -f ~/substation.log
```

This shows:

- All HTTP requests and responses
- Authentication token exchange
- API endpoint discovery
- Cache hit/miss statistics
- Performance metrics

## First Steps

### 1. Launch Substation

Start Substation with your configured cloud:

```bash
substation --cloud mycloud
```

When you start Substation, you'll see the main dashboard showing an overview of your OpenStack resources:

![Substation Startup](../assets/substation-startup.png)

**Initial Loading:**

- Phase 1: Critical resources (servers, networks, flavors) load first (~1s)
- Phase 2: Secondary resources (volumes, images, keypairs) load next (~2s)
- Phase 3: Expensive resources (ports, security groups) load in background (~5s)

### 2. Understanding the Dashboard

The dashboard shows:

- **Resource Summary**: Count of servers, networks, volumes, images
- **Recent Activity**: Latest changes in your cloud
- **Health Status**: OpenStack service health indicators
- **Performance Metrics**: Cache hit rate, API response times

### 3. Navigate Between Views

Press single keys to switch between resource views:

| Key | View | Description |
|-----|------|-------------|
| `d` | Dashboard | Resource overview and health |
| `s` | Servers | Compute instances (VMs) |
| `n` | Networks | Virtual networks |
| `v` | Volumes | Block storage |
| `i` | Images | OS images and snapshots |
| `f` | Flavors | Instance sizes/types |
| `g` | Server Groups | Anti-affinity groups |
| `e` | Security Groups | Firewall rules |
| `u` | Subnets | Network subnets |
| `p` | Ports | Network interfaces |
| `r` | Routers | Virtual routers |
| `l` | Floating IPs | Public IP addresses |
| `b` | Barbican | Secrets management |
| `o` | Octavia | Load balancers |
| `j` | Swift | Object storage |

### 4. Working with Resource Lists

**Navigate Lists:**

```
↑/↓ or j/k    Move selection up/down
Page Up/Down  Scroll by page
Home/End      Jump to start/end
```

**View Details:**

1. Navigate to any resource (e.g., press `s` for servers)
2. Use arrow keys to select a server
3. Press `Space` or `Enter` to view full details
4. Press `Esc` to return to the list

![Substation Image Show](../assets/substation-image-show.png)

### 5. Searching for Resources

**Local Search (fast, filters current view):**

```
/ (slash)     Start local search
Type query    Results filter as you type
Esc           Clear search
```

**Cross-Service Search (searches all services):**

```
z             Open advanced search
Type query    Searches Nova, Neutron, Cinder, Glance, Keystone, Swift
Enter         Execute search (< 500ms typical)
```

### 6. Refreshing Data

**Manual Refresh:**

```
r             Refresh current view (uses cache if available)
c             Purge ALL caches and force fresh data from API
```

**Note:** Pressing `c` clears L1, L2, and L3 caches. Next operations will be slower while cache rebuilds.

### 7. Creating Resources

**Example: Creating a Server**

1. Press `s` to view servers
2. Press `n` for "New Server" (or follow on-screen prompts)
3. Fill in the form:
   - Server name
   - Select flavor (instance size)
   - Select image (OS)
   - Select network(s)
   - Optional: Add security groups, keypairs
4. Press `Enter` to create
5. Watch real-time status as server builds

**Other Creation Workflows:**

- **Networks**: Press `n` in network view
- **Volumes**: Press `n` in volume view
- **Security Groups**: Press `n` in security group view

## Essential Keyboard Shortcuts

### Global Commands

| Key | Action | Description |
|-----|--------|-------------|
| `?` | Show Help | Context-aware help for current view |
| `q` | Quit | Exit Substation |
| `r` | Refresh | Refresh current view data |
| `c` | Cache Purge | Clear ALL caches (use when data is stale) |
| `z` | Advanced Search | Cross-service search |
| `d` | Dashboard | Return to dashboard |

### List Navigation

| Key | Action | Alternative |
|-----|--------|-------------|
| `↑/↓` | Navigate up/down | `j/k` (vim-style) |
| `Page Up/Down` | Scroll by page | - |
| `Home/End` | Jump to start/end | `g/G` (vim-style) |
| `Space` | View details | `Enter` |
| `/` | Local search/filter | - |
| `Esc` | Go back | `q` in detail view |

### Resource Management

| Key | Action | Context |
|-----|--------|---------|
| `n` | New/Create | Resource lists |
| `d` | Delete | Selected resource |
| `e` | Edit/Modify | Selected resource |
| `a` | Attach/Associate | Volumes, networks |
| `x` | Detach/Disassociate | Volumes, networks |

## Common Workflows

### Workflow 1: List Your Servers

```bash
# Launch Substation
substation --cloud mycloud

# Press 's' to view servers
# Use ↑/↓ to navigate
# Press Space to view details
# Press Esc to go back
```

### Workflow 2: Create a New Server

```bash
# Launch Substation
substation --cloud mycloud

# Press 's' for servers
# Press 'n' for new server
# Fill in:
#   - Name: web-server-01
#   - Flavor: m1.medium
#   - Image: Ubuntu 22.04
#   - Network: private-network
# Press Enter to create
```

### Workflow 3: Search Across All Resources

```bash
# Launch Substation
substation --cloud mycloud

# Press 'z' for advanced search
# Type: "prod"
# Press Enter
# Results show all resources matching "prod" from:
#   - Servers (Nova)
#   - Networks (Neutron)
#   - Volumes (Cinder)
#   - Images (Glance)
#   - Users (Keystone)
#   - Containers (Swift)
```

### Workflow 4: Force Fresh Data

```bash
# When your data looks stale or wrong
# Press 'c' to purge ALL caches
# Press 'r' to refresh current view
# Fresh data loaded from OpenStack API (slower, but accurate)
```

## Troubleshooting First Connection

### Authentication Failures

**Symptom:** "Authentication failed" error

**Solutions:**

1. Verify `clouds.yaml` syntax:

   ```bash
   # Check file exists
   ls -l ~/.config/openstack/clouds.yaml

   # Validate YAML syntax
   python3 -c "import yaml; yaml.safe_load(open('~/.config/openstack/clouds.yaml'))"
   ```

2. Test credentials with OpenStack CLI:

   ```bash
   openstack --os-cloud mycloud server list
   ```

3. Enable wiretap mode to see auth details:

   ```bash
   substation --cloud mycloud --wiretap
   tail -f ~/substation.log
   ```

### Endpoint Not Found

**Symptom:** "Service endpoint not found" error

**Solutions:**

1. Verify region name matches your OpenStack deployment
2. Check service catalog:

   ```bash
   openstack --os-cloud mycloud catalog list
   ```

3. Ensure required services are available (Keystone, Nova, Neutron)

### Slow Performance

**Symptom:** Everything takes forever to load

**Likely Causes:**

1. **Slow OpenStack API** (most common): Your cloud, not Substation
   - Enable wiretap to measure actual API response times
   - Expected: < 2s per API call
   - If seeing > 5s, your OpenStack cluster needs attention

2. **Network latency**: Check connectivity to OpenStack endpoints
3. **Large dataset**: 50K+ servers? Enable pagination in config

## Next Steps

Now that you're up and running, explore:

- **[User Guide](../user-guide/index.md)**: Comprehensive usage documentation and all keyboard shortcuts
- **[OpenStack Integration](../openstack/index.md)**: Understanding which OpenStack services are supported
- **[Performance](../performance/index.md)**: Tuning cache settings for your environment
- **[Troubleshooting](../troubleshooting/index.md)**: Solutions to common problems

## Getting Help

- **Built-in Help**: Press `?` at any time for context-aware help
- **Documentation**: Complete guides in this documentation site
- **GitHub Issues**: [Report bugs and request features](https://github.com/cloudnull/substation/issues)
- **Logs**: Enable `--wiretap` and check `~/substation.log` for debugging
