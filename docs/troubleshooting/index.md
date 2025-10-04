# Troubleshooting Guide

This comprehensive guide helps you diagnose and resolve common issues with Substation. Each section includes symptoms, causes, solutions, and prevention strategies.

## Quick Diagnostics

### Wiretap Mode (Debug Logging)

Enable wiretap mode for detailed API call logging:

```bash
# Enable detailed logging to file
substation --cloud mycloud --wiretap

# View logs in real-time
tail -f ~/substation.log
```

**Wiretap Mode Shows:**

- All HTTP requests (method, URL, headers)
- All HTTP responses (status code, body, timing)
- Authentication token exchange details
- Service catalog and endpoint discovery
- Cache hit/miss statistics for each API call
- Performance metrics (response times, throughput)

**Example Output:**

```text
[2025-09-30 15:23:45] -> POST https://keystone.example.com:5000/v3/auth/tokens
[2025-09-30 15:23:45] <- 201 Created (234ms)
[2025-09-30 15:23:46] CACHE HIT: servers (L1, 0.8ms)
[2025-09-30 15:23:47] -> GET https://nova.example.com:8774/v2.1/servers/detail
[2025-09-30 15:23:49] <- 200 OK (2134ms)
[2025-09-30 15:23:49] CACHE STORE: servers (TTL: 120s)
```

### Quick Health Check

Press `h` in Substation to view the health dashboard showing:

- OpenStack service health status
- Cache hit rates (target: 80%+)
- API response times (target: < 2s)
- Memory usage and pressure indicators
- Active telemetry alerts

## Common Issues

### Connection Problems

#### Issue: Cannot Connect to OpenStack

Substation uses the Clouds YAML file to source credentials and connection details.

**Symptoms:**

- "Connection refused" error
- "Unable to authenticate" message
- Timeout errors

Ensure the `auth_url` is correct and includes the API version (e.g., `/v3`).

**Diagnosis:**

```bash
# Test connectivity
curl -k https://keystone.example.com:5000/v3

# Verify credentials
openstack token issue

# Check Substation connection
substation test-connection --cloud production
```

**Solutions:**

1. **Verify Auth URL:**

```yaml
# Correct format (includes /v3)
auth:
  auth_url: https://keystone.example.com:5000/v3  ✓

# Incorrect format
auth:
  auth_url: https://keystone.example.com:5000     ✗
```

2. **Check Network Access:**

```bash
# Test network path
traceroute keystone.example.com

# Check firewall rules
sudo iptables -L | grep 5000

# Verify proxy settings
echo $HTTP_PROXY $HTTPS_PROXY
```

3. **SSL/TLS Issues:**

```yaml
# Disable SSL verification (testing only)
connection:
  verify_ssl: false

# Or provide CA certificate
connection:
  ca_certificate: /path/to/ca-bundle.crt
```

#### Issue: Authentication Failures

**Symptoms:**

- "401 Unauthorized" errors
- "Invalid credentials" message
- Token expiration issues

**Solutions:**

1. **Verify Credentials:**

```bash
# Test with OpenStack CLI
export OS_AUTH_URL=https://keystone.example.com:5000/v3
export OS_USERNAME=myuser
export OS_PASSWORD=mypass

openstack token issue
```

2. **Check Domain Configuration:**

```yaml
auth:
  username: myuser
  password: mypass
  project_name: myproject
  project_domain_name: default  # Often missing
  user_domain_name: default      # Often missing
```

3. **Use Application Credentials:**

```yaml
# More secure and reliable
auth:
  application_credential_id: abc123
  application_credential_secret: secret123
```

### Performance Issues

#### Issue: Slow Response Times - "Everything is Slow!"

**Reality Check First:** 99% of the time, slow performance is your OpenStack API, not Substation.

**Diagnosis Step 1: Identify the Culprit**

```bash
# Enable wiretap to measure actual API response times
substation --cloud mycloud --wiretap

# In another terminal, watch the logs
tail -f ~/substation.log | grep "ms)"
```

**What you'll see:**

```
CACHE HIT: servers (L1, 0.8ms)      <- Substation is fast
GET /servers/detail <- 200 (2134ms) <- OpenStack is slow
GET /networks <- 200 (4521ms)       <- OpenStack is very slow
```

**Interpreting Results:**

- **Cache HIT < 10ms**: Substation is working perfectly, enjoy the speed
- **API calls < 2 seconds**: Normal OpenStack performance
- **API calls 2-5 seconds**: OpenStack cluster under load (common)
- **API calls > 5 seconds**: OpenStack cluster has serious problems

**Solutions by Cause:**

**1. Slow OpenStack API (Most Common)**

You can't fix OpenStack from Substation, but you can minimize the pain:

```bash
# Increase cache TTLs to hit the API less often
# (Note: Substation doesn't currently expose this in config,
#  but defaults are tuned for typical deployments)

# Current defaults (optimized from testing):
# - Servers: 120s (2 min) - highly dynamic
# - Networks: 300s (5 min) - moderately stable
# - Images: 900s (15 min) - rarely change
# - Flavors: 900s (15 min) - basically static
```

**2. Low Cache Hit Rate**

Check your cache hit rate by pressing `h` in Substation (Health Dashboard).

**Target:** 80%+ cache hit rate

**If < 80% hit rate:**

```bash
# Are you constantly pressing 'c' (cache purge)?
# Don't do that unless data is actually stale.

# Are you switching between views rapidly?
# Each view may trigger cache refreshes.

# Large dataset (50K+ resources)?
# First-time cache warming takes longer.
```

**3. Memory Pressure Causing Cache Eviction**

Symptoms:

- Cache hit rate dropping over time
- Memory usage at 85%+ (Substation starts evicting cache)
- Frequent cache misses for recently accessed data

```bash
# Check memory usage
top -p $(pgrep substation)

# If memory usage is high and cache hit rate is low:
# The system is evicting cache due to memory pressure
# This is by design to prevent OOM

# Solution: Close other applications or increase system RAM
```

**4. First-Time Loads (Expected)**

The first time you view any resource type:

- Cache is empty (MISS is expected)
- API call required (slow)
- Subsequent views are fast (cache HIT)

**This is normal behavior.**

#### Issue: High Memory Usage

**Symptoms:**

- Memory usage grows over time
- Substation using > 500MB RAM
- System becomes sluggish

**Expected Memory Usage:**

- Base application: ~200MB
- Cache for 10,000 resources: ~100MB additional
- Total typical usage: 200-400MB

**Diagnosis:**

```bash
# Check actual memory usage
ps aux | grep substation

# Monitor over time
watch -n 5 'ps aux | grep substation'
```

**Common Causes:**

**1. Large Dataset (50K+ Resources)**

This is expected behavior:

```
10,000 resources  = ~300MB total
50,000 resources  = ~500MB total
100,000 resources = ~800MB total
```

**Solution:** This is normal for large deployments. If memory is constrained, consider:

- Filtering views (use `/` to filter lists)
- Project-scoped credentials (reduce visible resources)
- Increase system RAM

**2. Memory Leak (Unlikely, but Possible)**

If memory grows continuously without stabilizing:

```bash
# Enable memory profiling (if available)
substation --cloud mycloud --profile-memory

# Report issue with memory profile
# Memory leaks are bugs - please report them!
```

**3. Cache Not Evicting**

Substation auto-evicts cache at 85% memory threshold.

If you're not seeing eviction when memory is high:

```bash
# Manually purge cache
# Press 'c' in Substation

# Check if eviction is working by watching logs
substation --wiretap | grep EVICT
```

### Display Issues

#### Issue: Corrupted Terminal Display

**Symptoms:**

- Garbled characters
- Broken borders
- Incorrect colors

**Solutions:**

1. **Reset Terminal:**

```bash
# Quick reset
reset

# Full terminal reset
tput reset
clear
```

2. **Check Terminal Type:**

```bash
# Verify terminal
echo $TERM

# Set correct terminal
export TERM=xterm-256color
```

3. **Disable Unicode:**

```yaml
ui:
  unicode_borders: false
  ascii_only: true
```

#### Issue: Colors Not Working

**Solutions:**

1. **Check Terminal Support:**

```bash
# Test color support
tput colors

# Should return 256 for modern terminals
```

## OpenStack HTTP Error Codes

### 4xx Client Errors (Your Problem)

#### 400 Bad Request

**Meaning:** You sent invalid data to the OpenStack API.

**Common Causes:**

- Malformed JSON in request body
- Missing required fields (e.g., creating server without flavor)
- Invalid UUIDs or IDs
- Field value out of range (e.g., negative volume size)

**Example:**

```
Creating server without specifying a flavor ID
```

**Solution:**

```bash
# Enable wiretap to see exact request being sent
substation --wiretap

# Check logs for the malformed request
grep "POST.*servers" ~/substation.log -A 20
```

#### 401 Unauthorized

**Meaning:** Authentication failed or token expired.

**Common Causes:**

- Invalid credentials in `clouds.yaml`
- Token expired (Keystone tokens typically last 1 hour)
- Project scope incorrect
- Application credential revoked

**Solution:**

```bash
# Test credentials directly
openstack --os-cloud mycloud token issue

# If token works but Substation fails:
# Check that domains are specified correctly
auth:
  username: myuser
  password: mypass
  project_name: myproject
  project_domain_name: default  # Required!
  user_domain_name: default      # Required!
```

**Auto-Recovery:** Substation automatically refreshes tokens 5 minutes before expiration.

#### 403 Forbidden

**Meaning:** You're authenticated, but don't have permission.

**Common Causes:**

- Insufficient role assignments (need admin, member, or reader role)
- Wrong project scope (viewing resources in different project)
- Policy restrictions (some operations require admin)
- Quota exhausted (can't create more resources)

**Examples:**

```
Member role trying to create load balancer -> May need admin
Viewing servers in different project -> Need project scope
Creating 51st server when quota is 50 -> Quota exceeded
```

**Solution:**

```bash
# Check your current role assignments
openstack role assignment list --user myuser --project myproject

# Check quotas
openstack quota show myproject

# Request quota increase or delete unused resources
```

#### 404 Not Found

**Meaning:** Resource doesn't exist.

**Common Causes:**

- Resource was deleted
- Wrong region (resource exists in different region)
- Wrong project scope
- Typo in UUID

**Solution:**

```bash
# Verify resource exists
openstack server show <uuid>

# Check region
openstack --os-region-name RegionTwo server show <uuid>

# Refresh Substation cache (data may be stale)
# Press 'c' in Substation to purge cache
```

#### 409 Conflict

**Meaning:** Resource state conflicts with requested operation.

**Common Causes:**

- Server not in correct state (e.g., deleting while building)
- Resource already exists (duplicate name when creating)
- Resource in use (detaching volume while server running)
- Port already attached

**Examples:**

```
Deleting server that's currently building -> Wait for ACTIVE
Creating network with duplicate name -> Use unique name
Detaching volume from running server -> Stop server first (or force detach)
```

**Solution:** Wait for resource to reach appropriate state, or fix the conflict.

#### 413 Request Entity Too Large / Rate Limited

**Meaning:** Too many requests or request too large.

**Common Causes:**

- API rate limiting kicked in (too many requests/second)
- Request body too large (e.g., huge JSON payload)
- Quota limits reached

**Substation's Built-in Protection:**

- Exponential backoff retry (automatic)
- Connection pooling (prevents connection exhaustion)
- Request throttling (prevents overwhelming API)

**If you see this error:**

```bash
# Substation will automatically retry with backoff:
# Attempt 1: Immediate
# Attempt 2: Wait 1 second
# Attempt 3: Wait 2 seconds
# Attempt 4: Wait 4 seconds
# Then give up

# Check logs for retry attempts
grep "retry" ~/substation.log -i
```

### 5xx Server Errors (OpenStack's Problem)

#### 500 Internal Server Error

**Meaning:** OpenStack service crashed or encountered unexpected error.

**Not Your Fault.** The OpenStack service has a bug or misconfiguration.

**Solution:**

```bash
# Substation will automatically retry (up to 3 times)
# Check OpenStack service logs (if you're the admin)

# As a user, wait and try again later
# Or contact your OpenStack administrator
```

#### 503 Service Unavailable

**Meaning:** Service is down, overloaded, or in maintenance.

**Common Causes:**

- Service restarting
- Database connection lost
- Message queue (RabbitMQ) down
- Planned maintenance

**Solution:**

```bash
# Wait and retry (Substation does this automatically)
# Check service status:
openstack endpoint list  # If this works, Keystone is up

# Check service-specific endpoints
curl https://nova.example.com:8774/
```

### Substation-Specific Errors

#### `OpenStackError.endpointNotFound(service: "nova")`

**Meaning:** Service not in Keystone catalog.

**Common Causes:**

- Service not installed (e.g., Octavia not available)
- Wrong region specified
- Service disabled in your deployment

**Solution:**

```bash
# List available services
openstack catalog list

# Check if service exists in your region
openstack endpoint list --service nova --region RegionOne

# If service is missing, it's not available in your deployment
```

#### `OpenStackError.decodingError`

**Meaning:** API returned malformed JSON or unexpected format.

**Causes:**

- API microversion mismatch
- Buggy OpenStack deployment
- Proxy/firewall corrupting responses

**Solution:**

```bash
# Enable wiretap to see raw response
substation --wiretap

# Check for microversion issues in logs
grep "microversion" ~/substation.log -i

# This is usually a bug - report with full logs
```

#### `CacheError: Eviction failed`

**Meaning:** MemoryKit tried to evict cache but couldn't.

**This is rare and indicates a bug.**

**Solution:**

```bash
# Manually purge cache (press 'c' in Substation)
# Restart Substation
# Report bug with logs
```

## Debug Techniques

### Trace API Calls

```bash
# Trace all API calls
substation --wiretap

# Output:
[2024-01-15 10:23:45] -> GET /v2.1/servers
[2024-01-15 10:23:45] <- 200 OK (145ms)
[2024-01-15 10:23:46] -> POST /v2.1/servers/abc-123/action
[2024-01-15 10:23:47] <- 202 Accepted (523ms)
```

### Network Debugging

```bash
# Capture network traffic
tcpdump -i any -w substation.pcap host keystone.example.com

# Use proxy for inspection
export HTTPS_PROXY=http://localhost:8080
substation --cloud production
```

## Platform-Specific Issues

### macOS

#### Issue: Keychain Access

```bash
# Grant keychain access
security unlock-keychain

# Reset keychain entry
security delete-generic-password -s "Substation"
```

#### Issue: Terminal Colors

```bash
# Use Terminal.app settings
# Preferences -> Profiles -> Advanced -> Set TERM to xterm-256color

# Or use iTerm2
export TERM=xterm-256color
```

### Linux

#### Issue: Permission Denied

```bash
# Check file permissions
ls -la ~/.substation/

# Fix permissions
chmod 700 ~/.substation
chmod 600 ~/.substation/config.yaml
```

#### Issue: Missing Libraries

```bash
# Ubuntu/Debian
sudo apt-get install libncurses5

# RHEL/CentOS
sudo yum install ncurses

# Arch
sudo pacman -S ncurses
```

## Getting Help

### Community Resources

- **GitHub Releases**: [github.com/cloudnull/substation/releases](https://github.com/cloudnull/substation/releases)
- **GitHub Issues**: [github.com/cloudnull/substation/issues](https://github.com/cloudnull/substation/issues)
- **Documentation**: [substation.cloud](https://substation.cloud)
- **Stack Overflow**: Tag `substation-tui`

### Diagnostic Commands

```bash
# System information
substation info

# Configuration check
substation config validate

# Connection test
substation test-connection

# Performance report
substation performance report

# Health check
substation health-check --all
```
