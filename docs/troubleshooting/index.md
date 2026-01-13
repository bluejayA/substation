# Troubleshooting Guide

Look, things break. APIs timeout at the worst possible moment, authentication tokens expire mid-operation, and sometimes your terminal just decides to render garbage instead of beautiful TUI borders. We've spent countless 3 AM debugging sessions on these exact issues, so you don't have to suffer alone.

This guide is organized by problem severity. Critical issues that prevent you from connecting are at the top. Performance quirks and optimization tips are in the middle. The weird edge cases that probably don't affect you (but might) are toward the bottom.

## Quick Diagnostics: Your First Stop

Before diving into specific problems, these two commands will solve 80% of your issues.

### Wiretap Mode: See What's Really Happening

Nine times out of ten, when something feels broken, you need to see what the API is actually doing. Wiretap mode shows you every HTTP request and response, complete with timing data.

```bash
# Enable detailed logging to file
substation --cloud mycloud --wiretap

# View logs in real-time
tail -f ~/substation.log
```

Wiretap mode reveals the full conversation between Substation and OpenStack. You'll see all HTTP requests with their methods, URLs, and headers. Every response comes back with status codes, response bodies, and precise timing measurements. Authentication token exchanges, service catalog discovery, cache hit and miss statistics, and performance metrics all flow through the wiretap.

Here's what actual wiretap output looks like:

```text
[2025-09-30 15:23:45] -> POST https://keystone.example.com:5000/v3/auth/tokens
[2025-09-30 15:23:45] <- 201 Created (234ms)
[2025-09-30 15:23:46] CACHE HIT: servers (L1, 0.8ms)
[2025-09-30 15:23:47] -> GET https://nova.example.com:8774/v2.1/servers/detail
[2025-09-30 15:23:49] <- 200 OK (2134ms)
[2025-09-30 15:23:49] CACHE STORE: servers (TTL: 120s)
```

Notice that cache hit took less than a millisecond, while the actual API call took over two seconds. This pattern tells you everything you need to know about where your performance problems actually live.

### Quick Health Check: The Dashboard View

Type `:health<Enter>` (or just `:h<Enter>` if you're lazy) to see the health dashboard. This single view shows OpenStack service health status, cache hit rates with a target of 80% or higher, API response times that should stay under 2 seconds, memory usage with pressure indicators, and active telemetry alerts.

If your cache hit rate is above 80% and API response times are under 2 seconds, Substation is working perfectly. Any performance issues you're experiencing are almost certainly on the OpenStack side.

## Critical: Connection and Authentication

These are the showstoppers. If you can't connect or authenticate, nothing else matters.

### Cannot Connect to OpenStack

The classic error messages: "Connection refused", "Unable to authenticate", or the dreaded timeout that makes you wonder if the network cable is even plugged in. We've all been there, staring at a terminal waiting for a connection that will never come.

Substation uses your clouds.yaml file for credentials and connection details. The most common mistake is forgetting to include the API version in your auth_url. Here's the difference:

```yaml
# Correct format (includes /v3)
auth:
  auth_url: https://keystone.example.com:5000/v3

# Incorrect format - will fail
auth:
  auth_url: https://keystone.example.com:5000
```

That trailing `/v3` matters. Without it, you're trying to talk to Keystone's front door instead of the actual API endpoint.

Test your connectivity step by step. First, verify the endpoint responds at all with `curl -k https://keystone.example.com:5000/v3`. Then check if your credentials work using `openstack token issue`. Finally, test Substation's connection with `substation test-connection --cloud production`.

If curl works but Substation fails, the problem is in your clouds.yaml configuration. Check network access by running `traceroute keystone.example.com` and verify no firewall rules are blocking port 5000 with `sudo iptables -L | grep 5000`. Don't forget to check proxy settings with `echo $HTTP_PROXY $HTTPS_PROXY` because environment variables have a habit of interfering when you least expect it.

SSL/TLS issues deserve special mention because they're infuriating to debug. For testing purposes only, you can disable SSL verification:

```yaml
connection:
  verify_ssl: false
```

In production, provide the actual CA certificate:

```yaml
connection:
  ca_certificate: /path/to/ca-bundle.crt
```

### Authentication Failures

"401 Unauthorized" is the API's way of saying "I don't know who you are." This usually means invalid credentials, but sometimes it means your token expired mid-session or your domain configuration is incomplete.

Test your credentials outside Substation first. Export the environment variables and try to get a token:

```bash
export OS_AUTH_URL=https://keystone.example.com:5000/v3
export OS_USERNAME=myuser
export OS_PASSWORD=mypass

openstack token issue
```

If that works, the problem is in how you've configured clouds.yaml. The most commonly forgotten fields are the domain names:

```yaml
auth:
  username: myuser
  password: mypass
  project_name: myproject
  project_domain_name: default  # Often missing
  user_domain_name: default      # Often missing
```

OpenStack's domain system confuses everyone at first. Just remember that users and projects both exist within domains, and you need to specify which ones.

For production systems, use application credentials instead of passwords. They're more secure, they don't expire unexpectedly, and they work more reliably:

```yaml
auth:
  application_credential_id: abc123
  application_credential_secret: secret123
```

### Authentication Timeouts

If you're seeing "Authentication failed" errors, timeouts during login, or token expiration errors, the cause is usually Keystone service being slow or down, network latency, token TTL being too short, or simply invalid credentials.

Test Keystone directly to isolate the problem:

```bash
openstack token issue
curl -I https://keystone.example.com:5000/v3
tail -f ~/substation.log | grep -i auth
```

If Keystone itself is the problem, check the service health on the controller node with `systemctl status apache2` (or `httpd` depending on your distribution) and review logs with `journalctl -u apache2 -f`.

Authentication tokens are cached for 1 hour by default. If tokens seem stale, use `:cache-purge<Enter>` (or `:cc<Enter>`) to clear the cache and force re-authentication. Verify the token TTL in your Keystone configuration matches what Substation expects.

## Performance: When Everything Feels Slow

For background on Substation's performance architecture, see the [Performance Overview](../performance/index.md).

### The Reality Check

Here's the truth: 99% of the time, slow performance is your OpenStack API, not Substation. This isn't speculation. We've profiled this extensively. Cache hits take less than 10 milliseconds. The problem is that API call taking 4 seconds to return a list of servers.

Start by identifying the actual culprit. Enable wiretap mode and watch the logs:

```bash
# Enable wiretap to measure actual API response times
substation --cloud mycloud --wiretap

# In another terminal, watch the logs
tail -f ~/substation.log | grep "ms)"
```

You'll see output like this:

```
CACHE HIT: servers (L1, 0.8ms)      <- Substation is fast
GET /servers/detail <- 200 (2134ms) <- OpenStack is slow
GET /networks <- 200 (4521ms)       <- OpenStack is very slow
```

Interpret these numbers honestly. Cache hits under 10ms mean Substation is working perfectly. API calls under 2 seconds are normal OpenStack performance. Response times between 2 and 5 seconds indicate your OpenStack cluster is under load, which is common in busy environments. Anything over 5 seconds means OpenStack has serious problems that no TUI can fix.

### What You Can Actually Fix

You can't make OpenStack's API faster, but you can minimize how often you hit it. Substation's cache defaults are already tuned based on extensive production testing, but understanding them helps you work with the system instead of against it.

Authentication tokens are cached for 3600 seconds (1 hour) matching typical Keystone token lifetime. Service endpoints and quotas get 1800 seconds (30 minutes) because they're semi-static. Flavors and volume types are cached for 900 seconds (15 minutes) since they're basically static in most deployments. Keypairs, images, networks, and security groups get 300 seconds (5 minutes) as moderately dynamic resources. Volume snapshots and object storage have 180 second (3 minute) TTLs because storage is dynamic. Servers, volumes, ports, and floating IPs are cached for only 120 seconds (2 minutes) because they're highly dynamic and users expect recent changes to appear quickly.

Check your cache hit rate by pressing `h` for the health dashboard. Target 80% or higher. If you're seeing lower hit rates, ask yourself some hard questions. Are you constantly pressing 'c' to purge the cache? Stop doing that unless data is actually stale. Are you switching between views rapidly? Each view may trigger cache refreshes. Do you have a massive dataset with 50,000+ resources? First-time cache warming takes longer, and that's expected.

### Memory Pressure and Cache Eviction

Memory management is automatic in Substation, but it helps to understand what's happening. The base application uses about 200MB of RAM. Cache for 10,000 resources adds roughly 100MB. Typical total usage runs between 200 and 400MB.

If you're seeing cache hit rates drop over time, memory usage climbing above 85%, and frequent cache misses for recently accessed data, you're experiencing memory pressure. Substation will automatically evict cache entries to prevent running out of memory entirely. This is by design.

Check actual memory usage with `ps aux | grep substation` or monitor it over time with `watch -n 5 'ps aux | grep substation'`.

For large deployments, high memory usage is normal and expected. A deployment with 10,000 resources will use around 300MB. Scale that to 50,000 resources and you're looking at 500MB. At 100,000 resources, expect 800MB. If memory is constrained, filter views using `/` to search and reduce visible data, consider using project-scoped credentials to limit visible resources, or just add more RAM to your system.

Memory leaks are rare, but if you see memory growing continuously without stabilizing, that's a bug. Report it with memory profiling data if available via `substation --cloud mycloud --profile-memory`.

### First-Time Loads Are Expected to Be Slow

The first time you view any resource type, the cache is empty. A cache miss is expected. The API call is required and will be slow. Subsequent views are fast thanks to cache hits. This is completely normal behavior and not something to fix.

### High Memory Usage: When Things Get Bloated

If Substation is consuming more than 500MB of memory, your system feels sluggish, or you're getting warnings about memory pressure, something needs attention. The usual culprits are cache sizes too large for your environment, too many resources being cached, or in rare cases actual memory leaks.

Check current memory usage with `ps aux | grep substation` or press `h` for the health dashboard to see memory utilization metrics.

For immediate relief, purge the caches using `:cache-purge<Enter>` (or the shortcut `:cc<Enter>`). This clears all cached data immediately and memory usage should drop. The tradeoff is that your next operations will be slower while the cache rebuilds.

If you need a more sustainable fix, consider reducing cache TTLs. Shorter TTLs mean data expires faster and uses less memory. For environments with serious memory constraints, you can adjust the cache eviction threshold to start clearing data at 75% memory usage instead of 85%.

Keep your memory expectations realistic. The target is under 200MB for steady state operation. With 10,000 resources, expect under 300MB. If you're consistently using 500MB or more, something is wrong and worth investigating.

### Low Cache Hit Rates: Hitting the API Too Often

Your cache hit rate shows up on the health dashboard when you press `h`. Target 80% or higher in stable environments. In chaotic production environments with auto-scaling, 60% is acceptable. Below 60% is concerning and worth investigating.

Low hit rates usually mean TTLs are too short (cache expires before you need the data again), resources are changing very frequently, cache eviction is happening too often due to memory pressure, or there's a bug with cache keys (report this if suspected).

If your environment is relatively stable, increase TTLs to reduce API calls and improve hit rates. The tradeoff is staler data and slower visibility of new resources. If memory pressure is causing evictions, use `:cache-purge<Enter>` to clear stale data, consider increasing the eviction threshold, or add more RAM.

Some environments are just chaotic by nature. Production with auto-scaling means high churn, and lower hit rates are expected. Accept 60% in these situations rather than chasing an unrealistic target.

### Poor Search Performance: Finding Things Slowly

When searches consistently take more than 2 seconds, results appear slowly, or some services timeout giving you partial results, the problem is almost always OpenStack API performance, not Substation.

Enable wiretap mode and watch the logs to see which services are slow:

```bash
substation --cloud mycloud --wiretap
tail -f ~/substation.log | grep -i search
```

Test individual services to isolate the problem:

```bash
openstack server list --limit 1    # Test Nova
openstack network list --limit 1   # Test Neutron
openstack token issue              # Test Keystone auth
```

Improve your search patterns by using more specific queries. Searching for "prod-web-01" is faster than searching for just "prod" because there are fewer matches to process. Filter by specific services if you know which one you need. Accept partial results when timeouts occur.

Substation times out searches at 5 seconds intentionally. If OpenStack cannot respond in 5 seconds, something is wrong on the server side. Better to show partial results than wait forever. When a service times out, check that service's health directly, review the OpenStack logs for that service, and treat it as a canary indicating something is wrong with your OpenStack deployment.

### UI Rendering Issues: Sluggish Interface

If the UI feels sluggish or janky, frame rates drop below 30 FPS, or screen updates are delayed, you're dealing with rendering performance issues. These are distinct from terminal corruption problems covered in the Display Issues section below.

Common causes include terminal emulator performance limitations, SSH connection latency, too many screen updates from auto-refresh, and general rendering overhead.

Press `h` for the health dashboard and check the Rendering FPS metric. Target 60 FPS. 30+ FPS is acceptable. Below 30 FPS is poor and needs attention.

Reduce auto-refresh frequency using `:auto-refresh<Enter>` or `:toggle-refresh<Enter>` to toggle it off entirely. Increase the interval from 5 seconds to 10 or 30 seconds if you still want automatic updates. Use manual refresh with `r` when you specifically need current data.

Try a different terminal emulator if yours is slow. Check SSH connection latency if you're working remotely. Consider tmux or screen for session persistence which can also help with rendering performance.

Reduce the volume of data being displayed by filtering lists to show fewer items, using pagination, and limiting detail view depth.

### Slow API Response Times: The OpenStack Reality

When operations take more than 5 seconds and the UI feels frozen, start by understanding that 90% of the time the OpenStack API itself is slow, 8% of the time network latency between you and OpenStack is the culprit, and only about 2% of the time is it actually a Substation bug.

Enable wiretap mode to see all API calls with `substation --cloud mycloud --wiretap` and check the logs for API call duration (should be under 2 seconds), retry attempts (exponential backoff in action), 500 errors (OpenStack having a bad day), and timeouts (OpenStack having a really bad day).

If it is the OpenStack API (usually the case), check service health:

```bash
openstack endpoint list
openstack server list --all-projects --limit 1  # Test response time
```

On OpenStack controller nodes, check database connections with `mysql -e "SHOW PROCESSLIST;" | wc -l` to see the connection count. Check load on API nodes with `top` for CPU usage and `iostat` for disk I/O. Consider scaling your control plane by adding more API workers, more database read replicas, or optimizing database queries.

If network latency is the problem, measure it with `ping your-openstack-api.com` and check the network path with `traceroute your-openstack-api.com`. Consider running Substation closer to OpenStack in the same datacenter or network segment. Use VPN or direct connect instead of traversing the public internet.

The hard truth is that OpenStack APIs are slow. This is a known issue discussed at years of summits with countless patches, and they're still slow. Database queries are expensive especially with 50K servers. Keystone auth adds overhead to every request. Neutron network queries involve complex joins. Nova compute queries hit multiple tables.

Substation caches aggressively targeting 60-80% API reduction, parallelizes where possible, uses HTTP/2 connection pooling, and implements exponential backoff retry. But if the API takes 5 seconds to respond, we cannot make it 1 second. The bottleneck is OpenStack, not Substation.

### Performance Monitoring Checklist

**Daily Checks**

Press `h` for the health dashboard. Verify cache hit rate exceeds 60%. Confirm memory usage stays under 300MB. Check for API timeouts. Review search performance.

**Weekly Reviews**

Run a full benchmark suite with `substation benchmark`. Compare with baseline metrics. Review performance trends. Check for regressions. Update documentation if configurations changed.

**Monthly Maintenance**

Review TTL configurations to ensure they match your environment's needs. Optimize cache sizes based on actual usage patterns. Clean up old benchmark data. Update performance baselines. Plan optimization work for the next cycle.

For more details on performance tuning, see the [Performance Tuning Guide](../performance/tuning.md). For benchmark methodology and metrics, see [Performance Benchmarks](../performance/benchmarks.md). The [MemoryKit API Reference](../reference/api/memorykit.md) provides a deep dive into the caching subsystem.

### Quick Diagnosis Flowchart

When facing performance issues, work through this decision tree:

```
Performance Issue
    |
    |- Memory High?
    |   |- Yes -> Press 'c' to purge cache -> Reduce TTLs -> Increase eviction threshold
    |   +- No -> Continue
    |
    |- API Slow?
    |   |- Yes -> Check OpenStack health -> Check network -> Enable wiretap
    |   +- No -> Continue
    |
    |- Cache Hit Rate Low?
    |   |- Yes -> Increase TTLs -> Reduce eviction -> Check for high churn
    |   +- No -> Continue
    |
    |- Search Slow?
    |   |- Yes -> Check service health -> Use specific queries -> Check cache
    |   +- No -> Continue
    |
    +- UI Sluggish?
        |- Yes -> Reduce auto-refresh -> Check terminal -> Reduce data volume
        +- No -> Report issue (might be a bug)
```

## Display Issues: Terminal Problems

### Corrupted or Garbled Display

Sometimes terminals just lose their minds. Characters get garbled, borders break, colors invert randomly. The solution is usually a good old-fashioned reset.

Try `reset` for a quick reset or run `tput reset` followed by `clear` for a full terminal reset. Check your TERM environment variable with `echo $TERM` and set it correctly if needed with `export TERM=xterm-256color`.

If you're still seeing Unicode characters render incorrectly (which shouldn't happen since Substation is ASCII-only), you can explicitly configure it:

```yaml
ui:
  unicode_borders: false
  ascii_only: true
```

### Missing Colors

Terminal color support varies. Test it with `tput colors` which should return 256 for modern terminals. If it returns something lower, your terminal doesn't support 256 colors and you'll need to either upgrade your terminal emulator or accept monochrome output.

## OpenStack Compatibility: Version Questions

Substation is developed and tested against modern OpenStack releases starting from Stein. It doesn't enforce version requirements because that would be annoying and unhelpful. Instead, it attempts to connect to any Keystone v3 endpoint and uses whatever API features are available.

If you're running older releases, here's what to expect. Queens to Stein should work with most features. Pike or older may have compatibility issues with newer API features. Pre-Queens releases aren't supported because they don't have Keystone v3.

When troubleshooting version issues, verify your Keystone API version is v3 by checking that your auth_url ends with `/v3`. Confirm service availability since some features require specific services like Swift or Barbican. Be aware that API microversions mean newer operations may not work on older OpenStack deployments.

Use the `--wiretap` flag to see detailed API communication and identify exactly where version mismatches occur.

## HTTP Error Codes: What They Actually Mean

### 4xx Errors: Your Problem

#### 400 Bad Request

You sent invalid data to the OpenStack API. This typically means malformed JSON in the request body, missing required fields like trying to create a server without specifying a flavor, invalid UUIDs or IDs, or field values out of range such as negative volume sizes.

Enable wiretap to see the exact request being sent: `substation --wiretap`. Then check the logs with `grep "POST.*servers" ~/substation.log -A 20` to see the malformed request.

#### 401 Unauthorized

Authentication failed or your token expired. Keystone tokens typically last 1 hour, so if you've been working for a while, this might just be normal token expiration. Substation automatically refreshes tokens 5 minutes before expiration, but sometimes timing is off.

Test credentials directly with `openstack --os-cloud mycloud token issue`. If the token works but Substation fails, verify domains are specified correctly in your clouds.yaml:

```yaml
auth:
  username: myuser
  password: mypass
  project_name: myproject
  project_domain_name: default  # Required!
  user_domain_name: default      # Required!
```

#### 403 Forbidden

You're authenticated, but you don't have permission for that operation. Common causes include insufficient role assignments (you need admin, member, or reader role), wrong project scope (viewing resources in a different project), policy restrictions (some operations require admin), or quota exhaustion (can't create more resources).

Check your current role assignments with `openstack role assignment list --user myuser --project myproject` and verify quotas with `openstack quota show myproject`. Request a quota increase or delete unused resources to free up capacity.

#### 404 Not Found

The resource doesn't exist. Maybe it was deleted, or you're looking in the wrong region, or you have the wrong project scope, or there's a typo in the UUID.

Verify the resource exists with `openstack server show <uuid>`. Try checking different regions with `openstack --os-region-name RegionTwo server show <uuid>`. If the resource should exist, refresh Substation's cache by pressing 'c' because the data might be stale.

#### 409 Conflict

The resource state conflicts with your requested operation. Classic examples include trying to delete a server that's currently building (wait for ACTIVE state), creating a network with a duplicate name (use a unique name), or detaching a volume from a running server (stop the server first, or use force detach).

The solution is to wait for the resource to reach the appropriate state or fix the underlying conflict.

#### 413 Request Entity Too Large / Rate Limited

You've triggered API rate limiting by sending too many requests per second, the request body is too large, or you've hit quota limits. Substation has built-in protection with exponential backoff retry, connection pooling to prevent connection exhaustion, and request throttling to avoid overwhelming the API.

If you see this error, Substation will automatically retry with backoff. The first attempt is immediate. The second waits 1 second. The third waits 2 seconds. The fourth waits 4 seconds. Then it gives up. Check logs for retry attempts with `grep "retry" ~/substation.log -i`.

### 5xx Errors: OpenStack's Problem

#### 500 Internal Server Error

The OpenStack service crashed or encountered an unexpected error. This is not your fault. The OpenStack service has a bug or misconfiguration.

Substation will automatically retry up to 3 times. If you're an OpenStack admin, check the service logs. If you're a user, wait and try again later or contact your OpenStack administrator. There's nothing you can do from the client side to fix a server that's crashing.

#### 503 Service Unavailable

The service is down, overloaded, or in maintenance mode. Common causes include service restarts, database connection loss, message queue (RabbitMQ) failures, or planned maintenance windows.

Substation automatically waits and retries. Check service status with `openstack endpoint list` to verify Keystone is up. Test service-specific endpoints with `curl https://nova.example.com:8774/` to see if the service responds at all.

## Substation-Specific Errors

### OpenStackError.endpointNotFound

The service isn't in the Keystone catalog. This usually means the service isn't installed (Octavia isn't available in all deployments), you specified the wrong region, or the service is disabled in your particular deployment.

List available services with `openstack catalog list` and check if the service exists in your region with `openstack endpoint list --service nova --region RegionOne`. If the service is missing, it's simply not available in your deployment and you can't use features that depend on it.

### OpenStackError.decodingError

The API returned malformed JSON or an unexpected format. This indicates API microversion mismatch, a buggy OpenStack deployment, or a proxy/firewall corrupting responses.

Enable wiretap to see the raw response with `substation --wiretap`. Check for microversion issues in logs with `grep "microversion" ~/substation.log -i`. This is usually a bug, so report it with full logs.

### CacheError: Eviction failed

MemoryKit tried to evict cache entries but couldn't. This is rare and indicates a bug in the cache management system.

Manually purge the cache by pressing 'c' in Substation, restart the application, and report the bug with full logs.

## Debug Techniques for Deep Dives

### Tracing API Calls

Run `substation --wiretap` to trace all API calls. You'll see output like:

```
[2024-01-15 10:23:45] -> GET /v2.1/servers
[2024-01-15 10:23:45] <- 200 OK (145ms)
[2024-01-15 10:23:46] -> POST /v2.1/servers/abc-123/action
[2024-01-15 10:23:47] <- 202 Accepted (523ms)
```

This shows you exactly what's happening on the wire, with precise timing for every request and response.

### Network-Level Debugging

Capture network traffic with `tcpdump -i any -w substation.pcap host keystone.example.com` to see everything at the packet level. Use a proxy for inspection by setting `export HTTPS_PROXY=http://localhost:8080` before running `substation --cloud production`. This routes all traffic through a proxy like mitmproxy where you can inspect and modify requests.

## Platform-Specific Quirks

### macOS Issues

Keychain access sometimes causes problems. Grant keychain access with `security unlock-keychain` or reset the entry entirely with `security delete-generic-password -s "Substation"`.

Terminal colors in macOS Terminal.app need configuration. Go to Preferences, then Profiles, then Advanced, and set TERM to xterm-256color. Or just use iTerm2 which handles colors correctly by default.

### Linux Issues

Permission denied errors usually mean file permissions are wrong. Check with `ls -la ~/.substation/` and fix with `chmod 700 ~/.substation` followed by `chmod 600 ~/.substation/config.yaml`.

Missing ncurses libraries are common on minimal Linux installations. On Ubuntu/Debian, run `sudo apt install libncurses6`. On RHEL/CentOS, use `sudo yum install ncurses`. On Arch, try `sudo pacman -S ncurses`.

## Command Input Issues and Debugging

### Commands Not Working

If typing `:servers` doesn't navigate to the servers view, check whether the command is registered in ResourceRegistry, verify the ViewMode exists, and check logs for command execution.

Add missing commands to ResourceRegistry:

```swift
.myView: ["myview", "mv"],
```

### Selection Jumping When Filtering

This was a known issue where typing in the search box would reset selection to the top. It's fixed in v2.0 with ID-based selection tracking.

If you still see this behavior, verify `selectedResourceId` is being used instead of `selectedResultIndex`, check that `getSelectedIndex()` is called correctly, and confirm `moveSelection()` updates the ID properly.

### Enter Key Triggers Search Instead of Navigation

This is an input priority issue. Ensure Layer 1 handles Enter before UnifiedInputView processes it:

```swift
// In handleInput()
if priority == .navigation && key == 10 || key == 13 {
    navigateToDetailView()
    return true
}
```

### Fuzzy Matching Too Slow

If you experience lag when typing in command input, you might have too many aliases or inefficient matching logic. Reduce the number of aliases and add early exit in `rankedMatches()`:

```swift
if let limit = limit, foundCount >= limit * 2, score < 80 {
    break  // Stop if we have enough good matches
}
```

### Tab Completion Not Working

The Tab key should complete commands, but it only works when command input is active and there are matches to complete. Verify command input is active by checking `inputState.isCommandMode`, ensure `getSuggestions()` returns matches, and confirm Tab key (ASCII 9) is being handled by your input handler.

### Debugging Tips for Input Issues

Enable input logging to see what's happening:

```swift
InputPriority.logInput(key, layer: "Debug", handled: true)
```

Check command resolution to verify names resolve correctly:

```swift
let view = ResourceRegistry.shared.resolve("mycommand")
print("Resolved to: \(view)")
```

View ranked matches to understand fuzzy matching scores:

```swift
let matches = ResourceRegistry.shared.rankedMatches(for: "ser")
for match in matches {
    print("\(match.command): \(match.score)")
}
```

Monitor selection state to track what's selected:

```swift
print("Selected ID: \(selectedResourceId)")
print("Selected Index: \(getSelectedIndex(in: results))")
```

## Getting Help: When All Else Fails

We're active on GitHub and actually respond to issues. Check GitHub Releases at github.com/cloudnull/substation/releases for the latest version. Report bugs and request features at github.com/cloudnull/substation/issues. Read the full documentation at substation.cloud. For general questions, use Stack Overflow with the tag `substation-tui`.

Run these diagnostic commands when reporting issues so we have the context we need to help you:

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

Include the output of relevant commands when reporting issues. "It doesn't work" gives us nothing to work with. "Here's the wiretap output showing a 500 error from Nova" gives us everything we need.
