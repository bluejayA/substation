# Quick Start Guide

Get up and running with Substation in 1 minute.

## Installation

Choose the installation method that works best for you:

### Option 1: Docker (Easiest)

```bash
docker run --volume ~/.config/openstack:/root/.config/openstack \
           --interactive \
           --tty \
           --env TERM \
           --rm \
           ghcr.io/cloudnull/substation/substation:latest
```

### Option 2: Pre-built Binary

```bash
curl -L "https://github.com/cloudnull/substation/releases/latest/download/substation-$(uname -s)-$(uname -m)" -o substation
chmod +x substation
sudo mv substation /usr/local/bin/
```

### Option 3: Build from Source** (requires Swift 6.1+)

```bash
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
.build/release/substation
```

For detailed installation instructions including prerequisites, verification, and troubleshooting, see the **[Installation Guide](installation/index.md)**.

## Configuration

### 1. Create clouds.yaml

```bash
mkdir -p ~/.config/openstack
cat > ~/.config/openstack/clouds.yaml << 'EOF'
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret
      project_name: operations
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne
EOF
chmod 600 ~/.config/openstack/clouds.yaml
```

### 2. Test Connection

```bash
substation --cloud mycloud
```

For detailed configuration including authentication methods, multiple clouds, and advanced options, see the **[Configuration Guide](configuration/index.md)**.

## First Steps

### Navigation Basics

| Key | Action |
|-----|--------|
| `d` | Dashboard (start here) |
| `s` | View Servers |
| `n` | View Networks |
| `v` | View Volumes |
| `?` | Show Help |
| `q` | Quit |

### Common Operations

**View Resources:**

1. Press `s` to view servers
2. Use `↑/↓` to navigate
3. Press `Space` for details
4. Press `Esc` to go back

**Search Resources:**

1. Press `/` for quick search
2. Type your query
3. Press `Esc` to clear

**Refresh Data:**

- Press `r` to refresh current view
- Press `c` to purge cache and force refresh

## Essential Keyboard Shortcuts

### Navigation

| Key | View |
|-----|------|
| `d` | Dashboard |
| `s` | Servers |
| `n` | Networks |
| `v` | Volumes |
| `i` | Images |
| `f` | Flavors |
| `e` | Security Groups |

### Actions

| Key | Action |
|-----|--------|
| `↑/↓` | Navigate lists |
| `Space` | View details |
| `/` | Search |
| `r` | Refresh |
| `c` | Cache purge |
| `?` | Help |
| `q` | Quit |

## Common Workflows

### List Your Servers

1. Launch Substation: `substation --cloud mycloud`
2. Press `s` for servers
3. Use `↑/↓` to navigate
4. Press `Space` for server details

### Search Across Services

1. Press `z` for advanced search
2. Type your query (e.g., "prod")
3. Press `Enter`
4. Results from all services appear

### Purge Stale Cache

1. Press `c` to purge ALL caches
2. Press `r` to refresh current view
3. Fresh data loaded from API

## Troubleshooting

### Connection Issues

**Problem**: Can't connect to OpenStack

**Solution**: Verify auth_url includes `/v3`:

```yaml
# Correct
auth_url: https://keystone.example.com:5000/v3  ✓

# Wrong
auth_url: https://keystone.example.com:5000     ✗
```

### Slow Performance

**Problem**: Everything is slow

**Solution**: Enable wiretap to diagnose:

```bash
substation --cloud mycloud --wiretap
tail -f ~/substation.log | grep "ms)"
```

### Stale Data

**Problem**: Resources not showing up

**Solution**: Press `c` to purge cache, then `r` to refresh

## Next Steps

- **[Installation Guide](installation/index.md)** - Detailed installation options and troubleshooting
- **[Configuration Guide](configuration/index.md)** - Advanced clouds.yaml setup and authentication
- **[Getting Started](getting-started/index.md)** - Learn the concepts and first steps
- **[Navigation Guide](guides/operators/keyboard-shortcuts.md)** - Master all keyboard shortcuts
- **[Common Workflows](guides/operators/workflows.md)** - Learn everyday operations
- **[Troubleshooting](troubleshooting/index.md)** - Detailed problem solving

## Getting Help

- Press `?` at any time for context-aware help
- Check **[FAQ](reference/faq.md)** for common questions
- Report issues on **[GitHub](https://github.com/cloudnull/substation/issues)**
