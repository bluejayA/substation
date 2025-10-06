# Configuration Guide

This guide covers how to configure Substation to connect to your OpenStack cloud. Substation uses the standard `clouds.yaml` format, so if you already use OpenStack CLI tools, your existing configuration will work.

## Understanding clouds.yaml

Substation uses the same `clouds.yaml` format as the official Python OpenStack CLI. This means:

- Configuration is portable across tools (python-openstackclient, Substation, etc.)
- Standard OpenStack authentication methods are supported
- Multiple clouds can be managed from a single file
- Security best practices are built-in

**Configuration File Locations** (checked in order):

1. `./clouds.yaml` (current directory - highest priority)
2. `~/.config/openstack/clouds.yaml` (user config - recommended)
3. `/etc/openstack/clouds.yaml` (system-wide config)

## Quick Start Configuration

### Step 1: Create the Directory

```bash
# Create directory if it doesn't exist
mkdir -p ~/.config/openstack

# Create the file
touch ~/.config/openstack/clouds.yaml

# Set appropriate permissions (important for security!)
chmod 600 ~/.config/openstack/clouds.yaml
```

### Step 2: Add Your Cloud Configuration

Edit `~/.config/openstack/clouds.yaml` with your preferred editor:

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

**Important**: Replace the example values with your actual OpenStack credentials.

**Tip**: For production use, consider using `project_id` instead of `project_name` for more explicit project handling. See [ID-based Authentication](#id-based-authentication-recommended) for details.

### Step 3: Test Connection

```bash
# Launch Substation
substation --cloud mycloud

# Or set environment variable
export OS_CLOUD=mycloud
substation
```

If connection succeeds, you'll see the Substation dashboard. If it fails, see the [Troubleshooting](#troubleshooting-configuration) section below.

## Authentication Methods

Substation supports all standard OpenStack authentication methods. Choose the one that fits your environment.

### Password Authentication (Basic)

The most common authentication method uses username and password:

```yaml
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret123
      project_name: operations
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne
```

**Required Fields:**

- `auth_url` - Keystone endpoint (must include `/v3`)
- `username` - Your OpenStack username
- `password` - Your OpenStack password
- `project_name` - Project (tenant) to scope to
- `project_domain_name` - Domain of the project (usually "default")
- `user_domain_name` - Domain of the user (usually "default")

**Optional Fields:**

- `region_name` - Region to use (required if your cloud has multiple regions)

### ID-based Authentication

It is also possible to authenticate using resource IDs instead of names. This is more robust since IDs do not change, while names can be modified by admins.

```yaml
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret123
      project_id: a1b2c3d4e5f6g7h8i9j0
      user_domain_id: default
      project_domain_id: default
    region_name: RegionOne
```

**ID-based Parameters:**

- `project_id` - Unique project identifier (preferred over `project_name`)
- `user_domain_id` - Unique user domain identifier (preferred over `user_domain_name`)
- `project_domain_id` - Unique project domain identifier (preferred over `project_domain_name`)

**Benefits of Using IDs:**

- **Immutable** - IDs never change; names can be modified by admins
- **Faster** - No name-to-ID resolution lookups required
- **Unique** - IDs are globally unique; names can be duplicated across domains
- **Reliable** - Better for automation and production deployments

**Mixed Configuration (Best Practice):**

You can provide both names and IDs for maximum compatibility. IDs will be preferred when both are present:

```yaml
clouds:
  mycloud:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      username: operator
      password: secret123
      # IDs (preferred - used first)
      project_id: a1b2c3d4e5f6g7h8i9j0
      user_domain_id: default
      project_domain_id: default
      # Names (fallback - for documentation)
      project_name: operations
      user_domain_name: default
      project_domain_name: default
    region_name: RegionOne
```

**Finding Your Resource IDs:**

Use the OpenStack CLI to discover your resource IDs:

```bash
# Find your project ID
openstack project show <project-name> -f value -c id

# Find domain IDs
openstack domain show <domain-name> -f value -c id

# List all your projects with IDs
openstack project list --user <username>
```

### Application Credentials (Recommended)

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

**With Project Scoping (Optional):**

```yaml
clouds:
  production:
    auth:
      auth_url: https://openstack.example.com:5000/v3
      application_credential_id: "abc123..."
      application_credential_secret: "secret456..."
      # Optional: explicitly scope to a project
      project_id: a1b2c3d4e5f6g7h8i9j0  # Preferred
      # Or use project name
      project_name: production-ops
    region_name: RegionOne
```

**Benefits:**

- No password exposure in config file
- Can be easily revoked without changing passwords
- Can be scoped to specific roles/projects
- Can have expiration dates
- Supports both `project_id` and `project_name` for scoping

**Creating Application Credentials:**

```bash
# Using OpenStack CLI
openstack application credential create substation \
    --description "Substation TUI access" \
    --expiration "2026-12-31T23:59:59"

# Save the ID and secret to clouds.yaml
```

The output will include:

- `application_credential_id` - Use this in your clouds.yaml
- `application_credential_secret` - Use this in your clouds.yaml (shown only once!)

### Token Authentication (Temporary)

For temporary access, you can use an existing token:

```yaml
clouds:
  temp-access:
    auth:
      auth_url: https://keystone.example.com:5000/v3
      token: "gAAAAABh..."
      project_id: "abc123..."
    region_name: RegionOne
```

**Note**: Tokens expire (typically after 1 hour). This method is best for short-lived scripts or testing.

## Managing Multiple Clouds

Substation makes it easy to work with multiple OpenStack environments. Define all your clouds in a single `clouds.yaml` file:

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

**Use the OS_CLOUD Environment Variable:**

```bash
# Set default cloud
export OS_CLOUD=production

# Now just run substation
substation

# Override for one command
OS_CLOUD=staging substation
```

## Advanced Configuration

For advanced users, Substation supports extended configuration options to tune performance and behavior.

### Performance Tuning (Cache Settings)

Customize cache TTL (time-to-live) for different resource types:

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
```

**When to Customize Cache TTL:**

- **Short TTL (30-120s)**: Resources that change frequently (servers, volumes)
- **Medium TTL (300-600s)**: Resources that change occasionally (networks, security groups)
- **Long TTL (900-1800s)**: Resources that rarely change (flavors, images)

**Note**: Lower TTL = fresher data but more API calls. Higher TTL = faster performance but potentially stale data.

### API Configuration

Control API behavior and SSL verification:

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

    # API configuration (optional)
    interface: public         # public, internal, or admin
    verify: true              # SSL certificate verification
    cacert: /path/to/ca.pem   # Custom CA certificate
```

**Interface Types:**

- `public` (default) - Public API endpoints
- `internal` - Internal network endpoints (faster if on same network)
- `admin` - Admin endpoints (requires admin privileges)

**SSL Verification:**

- `verify: true` (default) - Validate SSL certificates (recommended)
- `verify: false` - Disable SSL validation (testing only, insecure)
- `cacert: /path/to/ca.pem` - Use custom CA certificate

!!! warning "SSL Verification"

    Disabling SSL verification (`verify: false`) is insecure and should only be used for testing. In production, always use valid certificates or provide a custom CA certificate via `cacert`.

### Using Custom CA Certificates

For self-signed certificates or custom CAs:

```yaml
clouds:
  internal-cloud:
    auth:
      auth_url: https://internal.example.com:5000/v3
      username: operator
      password: secret
      project_name: operations
      project_domain_name: default
      user_domain_name: default
    region_name: RegionOne
    verify: true
    cacert: /etc/ssl/certs/custom-ca.pem
```

## Environment Variables

Substation supports standard OpenStack environment variables for cloud selection:

- `OS_CLOUD` - Specify which cloud to use from clouds.yaml
- `OS_CLIENT_CONFIG_FILE` - Override default clouds.yaml location

**Examples:**

```bash
# Use specific cloud
export OS_CLOUD=production
substation

# Use custom clouds.yaml location
export OS_CLIENT_CONFIG_FILE=/path/to/custom-clouds.yaml
substation

# Combine both
export OS_CLOUD=staging
export OS_CLIENT_CONFIG_FILE=/path/to/custom-clouds.yaml
substation
```

**Note**: Substation does NOT support individual credential environment variables like `OS_USERNAME`, `OS_PASSWORD`, etc. You must use `clouds.yaml`.

## Security Best Practices

### File Permissions

Always secure your clouds.yaml file:

```bash
# Set restrictive permissions (user read/write only)
chmod 600 ~/.config/openstack/clouds.yaml

# Verify permissions
ls -l ~/.config/openstack/clouds.yaml
# Should show: -rw------- (600)
```

### Using Application Credentials

Prefer application credentials over passwords:

**Advantages:**

- No password exposure in config files
- Easy to revoke (no password change needed)
- Can be scoped to specific roles
- Can have expiration dates
- Can be restricted to specific services

**Creating Scoped Application Credentials:**

```bash
# Scoped to specific role
openstack application credential create substation \
    --role member \
    --description "Substation read-only access"

# With expiration
openstack application credential create substation \
    --expiration "2025-12-31T23:59:59" \
    --description "Temporary access for Q4 2025"

# Scoped to specific project
openstack application credential create substation \
    --project production-ops \
    --description "Production operations access"
```

### Avoiding Password Storage

If you must use password authentication, consider:

1. **Using a password manager** - Store clouds.yaml in encrypted storage
2. **Using OS keyring integration** - Store passwords in system keychain (advanced)
3. **Generating temporary tokens** - Use short-lived tokens for sensitive operations

### Revoking Access

If credentials are compromised:

**For Application Credentials:**

```bash
# List application credentials
openstack application credential list

# Revoke specific credential
openstack application credential delete <credential-id>
```

**For Passwords:**

```bash
# Change password immediately
openstack user password set

# Update clouds.yaml with new password
```

## Testing Your Configuration

### Basic Connection Test

```bash
# Test with a specific cloud
substation --cloud mycloud

# Expected: Dashboard loads with resource summary
# If fails: See error message and check configuration
```

### Enable Debug Logging (Wiretap Mode)

For troubleshooting connection issues:

```bash
# Enable detailed API logging
substation --cloud mycloud --wiretap

# Logs written to ~/substation.log
# In another terminal:
tail -f ~/substation.log
```

**Wiretap shows:**

- All HTTP requests and responses
- Authentication token exchange
- API endpoint discovery
- Cache hit/miss statistics
- Performance metrics

**Example Wiretap Output:**

```
[2025-10-05 10:15:23] AUTH: POST https://keystone.example.com:5000/v3/auth/tokens
[2025-10-05 10:15:24] AUTH: Token acquired (expires: 2025-10-05 11:15:24)
[2025-10-05 10:15:24] CATALOG: Discovered 12 services
[2025-10-05 10:15:25] GET https://nova.example.com:8774/v2.1/servers/detail <- 200 (423ms)
[2025-10-05 10:15:25] CACHE: Stored servers (TTL: 120s)
```

### Validate clouds.yaml Syntax

Before running Substation, verify your YAML syntax:

```bash
# Check file exists and has correct permissions
ls -l ~/.config/openstack/clouds.yaml

# Validate YAML syntax (requires Python)
python3 -c "import yaml; yaml.safe_load(open('$HOME/.config/openstack/clouds.yaml'))"

# If valid: no output
# If invalid: error message with line number
```

## Troubleshooting Configuration

### Authentication Failures

**Symptom**: "Authentication failed" error

**Common Causes:**

1. **Missing /v3 in auth_url**:

   ```yaml
   # Wrong
   auth_url: https://keystone.example.com:5000

   # Correct
   auth_url: https://keystone.example.com:5000/v3
   ```

2. **Missing domain fields**:

   ```yaml
   # Incomplete (will fail)
   auth:
     username: operator
     password: secret
     project_name: myproject

   # Complete (required)
   auth:
     username: operator
     password: secret
     project_name: myproject
     project_domain_name: default
     user_domain_name: default
   ```

3. **Incorrect credentials** - Verify with OpenStack CLI:

   ```bash
   openstack --os-cloud mycloud token issue
   ```

**Solution**: Enable wiretap mode to see detailed auth errors:

```bash
substation --cloud mycloud --wiretap
tail -f ~/substation.log
```

### Endpoint Not Found

**Symptom**: "Service endpoint not found" error

**Solutions:**

1. **Verify region name** matches your OpenStack deployment:

   ```bash
   openstack catalog list
   ```

2. **Check service catalog**:

   ```bash
   openstack endpoint list --service nova
   ```

3. **Ensure required services are available** (Keystone, Nova, Neutron minimum)

### SSL Certificate Errors

**Symptom**: "SSL certificate verification failed"

**Solutions:**

1. **For self-signed certificates**, provide CA cert:

   ```yaml
   verify: true
   cacert: /path/to/ca-bundle.pem
   ```

2. **For testing only**, disable verification:

   ```yaml
   verify: false  # Insecure, testing only
   ```

3. **For production**, get valid certificates from a CA

### Slow Connection / Timeouts

**Symptom**: Connection takes forever or times out

**Solutions:**

1. **Check network connectivity**:

   ```bash
   curl -k https://keystone.example.com:5000/v3
   ```

2. **Enable wiretap to measure API response times**:

   ```bash
   substation --cloud mycloud --wiretap
   tail -f ~/substation.log | grep "ms)"
   ```

3. **If API calls take > 5 seconds**, your OpenStack cluster has performance issues

### Configuration File Not Found

**Symptom**: "clouds.yaml not found"

**Solutions:**

1. **Check file exists in standard locations**:

   ```bash
   ls -l ~/.config/openstack/clouds.yaml
   ls -l /etc/openstack/clouds.yaml
   ls -l ./clouds.yaml
   ```

2. **Create directory and file**:

   ```bash
   mkdir -p ~/.config/openstack
   touch ~/.config/openstack/clouds.yaml
   chmod 600 ~/.config/openstack/clouds.yaml
   ```

3. **Or specify custom location**:

   ```bash
   export OS_CLIENT_CONFIG_FILE=/path/to/clouds.yaml
   substation --cloud mycloud
   ```

### YAML Syntax Errors

**Symptom**: "Failed to parse clouds.yaml"

**Solutions:**

1. **Validate YAML syntax**:

   ```bash
   python3 -c "import yaml; yaml.safe_load(open('$HOME/.config/openstack/clouds.yaml'))"
   ```

2. **Common issues**:
   - Incorrect indentation (YAML is whitespace-sensitive)
   - Missing colons after keys
   - Unquoted special characters

3. **Use a YAML validator** or editor with YAML support

## Next Steps

Now that Substation is configured, learn how to use it:

- **[Quick Start Guide](../quick-start.md)** - Get up and running in 1 minute
- **[Getting Started](../getting-started/index.md)** - Learn the basics
- **[Navigation Guide](../reference/operators/keyboard-shortcuts.md)** - Master keyboard shortcuts
- **[Troubleshooting](../troubleshooting/index.md)** - Solutions to common problems

## Getting Help

- **Built-in Help**: Press `?` at any time in Substation
- **Documentation**: [Complete guides](../index.md)
- **GitHub Issues**: [Report configuration issues](https://github.com/cloudnull/substation/issues)
- **FAQ**: [Common configuration questions](../reference/faq.md)
