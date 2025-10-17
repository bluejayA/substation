# Performance Troubleshooting

Common performance problems and their solutions.

## Common Performance Problems

### 1. High Memory Usage

**Symptoms**:

- Substation using > 500MB memory
- System feels sluggish
- OOM killer threatening your app

**Causes**:

- Cache sizes too large for your environment
- Too many resources being cached
- Memory leaks (shouldn't happen, but check)

**Diagnosis**:

```bash
# Check current memory usage
ps aux | grep substation

# Monitor in Substation
# Press 'h' for health dashboard
# Check memory utilization metrics
```

**Solutions**:

1. **Immediate relief** - Purge caches:
   - Use `:cache-purge<Enter>` (or `:cc<Enter>`) in Substation (purges all caches)
   - Next operations slower while cache rebuilds
   - Memory usage should drop immediately

2. **Short-term fix** - Reduce cache TTLs:

   ```swift
   // In CacheManager.swift
   case .server: return 60.0    // Reduce from 120s to 60s
   case .network: return 180.0  // Reduce from 300s to 180s
   ```

3. **Long-term fix** - Increase cache eviction threshold:

   ```swift
   // In MemoryManager.swift
   let evictionThreshold = 0.75  // Evict at 75% instead of 85%
   ```

**Memory Reality Check**:

- Target: < 200MB steady state
- With 10K resources: < 300MB
- If using 500MB+: Something's wrong

### 2. Slow API Response Times

**Symptoms**:

- Operations take > 5 seconds
- UI feels frozen
- Watching paint dry would be more exciting

**Causes** (in order of likelihood):

1. Your OpenStack API is slow (90% of cases)
2. Network latency between you and OpenStack (8% of cases)
3. Substation bug (2% of cases, report it)

**Diagnosis**:

```bash
# Enable wiretap mode to see ALL API calls
substation --cloud mycloud --wiretap

# Check the log file
tail -f ~/substation.log

# Look for:
# - API call duration (should be < 2s)
# - Retry attempts (exponential backoff in action)
# - 500 errors (OpenStack having a bad day)
# - Timeouts (OpenStack having a REALLY bad day)
```

**Solutions**:

**If it's the OpenStack API** (usually):

1. Check OpenStack service health:

   ```bash
   openstack endpoint list
   openstack server list --all-projects --limit 1  # Test response time
   ```

2. Check database connections on OpenStack controller:

   ```bash
   # On controller node
   mysql -e "SHOW PROCESSLIST;" | wc -l  # Connection count
   ```

3. Check load on OpenStack API nodes:

   ```bash
   # On API nodes
   top  # Check CPU usage
   iostat  # Check disk I/O
   ```

4. Consider scaling your OpenStack control plane
   - Add more API workers
   - Add more database read replicas
   - Optimize database queries

5. Accept that OpenStack is slow (sad but true)

**If it's network latency**:

1. Measure latency:

   ```bash
   ping your-openstack-api.com
   ```

2. Check network path:

   ```bash
   traceroute your-openstack-api.com
   ```

3. Consider running Substation closer to OpenStack
   - Same datacenter
   - Same network segment
   - Direct connect instead of VPN

4. Use VPN or direct connect if over internet

**If it's Substation** (unlikely but possible):

1. Update to latest version
2. Check GitHub issues: <https://github.com/cloudnull/substation/issues>
3. Report issue with wiretap logs
4. We'll investigate (we care about performance)

### The Hard Truth About OpenStack Performance

OpenStack APIs are slow. This is a known issue. Years of discussion. Multiple summits. Countless patches. Still slow.

**Why?**

- Database queries are expensive (especially with 50K servers)
- Keystone auth adds overhead to every request
- Neutron network queries involve complex joins
- Nova compute queries hit multiple tables

**What Substation Does**:

- Caches aggressively (60-80% API reduction)
- Parallelizes where possible (search, batch ops)
- Uses HTTP/2 connection pooling
- Implements exponential backoff retry

**But**: If the API takes 5 seconds to respond, we can't make it 1 second. The bottleneck is OpenStack, not Substation.

### 3. Low Cache Hit Rates

**Symptoms**:

- Cache hit rate < 60% (check health dashboard with `h`)
- Performance feels slow despite caching
- API calls happening too frequently

**Causes**:

- TTLs too short (cache expires too quickly)
- Resources changing very frequently
- Cache eviction happening too often (memory pressure)
- Using wrong cache keys (bug, report it)

**Diagnosis**:

```bash
# Check cache statistics in health dashboard
# Press 'h' in Substation

# Look for:
# - Hit rate < 60%: TTLs too short or high churn
# - High eviction count: Memory pressure
# - Miss rate > 40%: Cache not working
```

**Solutions**:

**1. Increase TTLs** (if environment is stable):

```swift
// In CacheManager.swift:100
case .server: return 300.0  // Increase from 2min to 5min
case .network: return 600.0  // Increase from 5min to 10min
```

**Benefits**: Fewer API calls, better hit rate
**Risks**: Staler data, slower to see new resources

**2. Reduce memory pressure** (if evictions are high):

- Use `:cache-purge<Enter>` (or `:cc<Enter>`) to purge stale data
- Increase cache eviction threshold (evict at 90% instead of 85%)
- Add more RAM to your system

**3. Accept high churn** (if resources change constantly):

- Some environments are just chaotic
- Production with auto-scaling = high churn
- Lower hit rates are expected
- 60% is acceptable in high-churn environments

**Cache Hit Rate Reality**:

- Target: 80%+ in stable environments
- Reality: 70%+ in production
- Acceptable: 60%+ in chaotic environments
- Concerning: < 60% (investigate)

### 4. Poor Search Performance

**Symptoms**:

- Searches take > 2 seconds consistently
- Search results appear slowly
- Some services timeout (partial results)

**Causes**:

- OpenStack APIs are slow (again, usually this)
- Too many resources to search through
- Network latency
- Search cache not effective

**Diagnosis**:

```bash
# Enable wiretap to see search API calls
substation --cloud mycloud --wiretap

# Check logs for:
# - Which services are slow
# - Timeout messages
# - API response times

tail -f ~/substation.log | grep -i search
```

**Solutions**:

**1. Check OpenStack service health**:

```bash
# Nova slow?
openstack server list --limit 1  # Test response time

# Neutron slow?
openstack network list --limit 1

# All services slow?
openstack token issue  # Test Keystone auth
```

**2. Review search patterns**:

- Use more specific queries ("prod-web-01" not just "prod")
- Filter by specific services if you know which one
- Accept partial results on timeout

**3. Check search cache**:

- In health dashboard (`h` key), check:
  - Search cache hit rate (target: 70%)
  - Search cache size
  - Recent searches
- Searches are cached (repeat searches should be instant)

### The 5-Second Search Timeout

We timeout searches at 5 seconds. This is intentional.

**Why?**

- If OpenStack can't respond in 5 seconds, something's wrong
- Better to show partial results than wait forever
- Operator waiting > 5 seconds = operator rage

**When it happens**:

- Service is down (partial results, missing that service)
- Service is overloaded (partial results, missing that service)
- Network is broken (partial results, timeouts)

**What to do**:

- Check the service that timed out
- Review OpenStack logs for that service
- Consider this a canary (something's wrong with OpenStack)

### 5. UI Rendering Issues

**Symptoms**:

- UI feels sluggish or janky
- Frame rate < 30 FPS
- Screen updates delayed

**Causes**:

- Terminal performance issues
- SSH connection latency
- Too many screen updates
- Rendering overhead

**Diagnosis**:

```bash
# Check rendering metrics
# Press 'h' for health dashboard
# Look at "Rendering FPS" metric

# Target: 60 FPS
# Acceptable: 30+ FPS
# Poor: < 30 FPS
```

**Solutions**:

**1. Reduce auto-refresh frequency**:

- Use `:auto-refresh<Enter>` (or `:toggle-refresh<Enter>`) to toggle auto-refresh
- Increase interval from 5s to 10s or 30s
- Manual refresh with `r` when needed

**2. Check terminal performance**:

- Try different terminal emulator
- Check SSH connection latency
- Consider tmux/screen for session persistence

**3. Reduce data volume**:

- Filter lists to show fewer items
- Use pagination
- Limit detail view depth

**4. Check system resources**:

```bash
# CPU usage
top

# Memory usage
free -h

# Disk I/O
iostat
```

### 6. Authentication Timeouts

**Symptoms**:

- "Authentication failed" errors
- Timeouts during login
- Token expiration errors

**Causes**:

- Keystone service slow or down
- Network latency
- Token TTL too short
- Invalid credentials

**Diagnosis**:

```bash
# Test Keystone directly
openstack token issue

# Check Keystone service health
curl -I https://keystone.example.com:5000/v3

# Check auth logs
tail -f ~/substation.log | grep -i auth
```

**Solutions**:

**1. Check Keystone health**:

```bash
# On Keystone controller
systemctl status apache2  # or httpd
journalctl -u apache2 -f  # Check logs
```

**2. Increase timeouts**:

```swift
OpenStackConfig(
    authUrl: "https://keystone.example.com:5000/v3",
    timeout: 60,  // Increase from 30s
    retryCount: 5  // Increase from 3
)
```

**3. Check token cache**:

- Authentication tokens cached for 1 hour
- Use `:cache-purge<Enter>` (or `:cc<Enter>`) to clear cache if tokens seem stale
- Verify token TTL in Keystone configuration

**4. Verify credentials**:

```bash
# Test with CLI
openstack --os-cloud mycloud server list
```

## Performance Monitoring Checklist

### Daily Checks

- [ ] Check health dashboard (`h` key)
- [ ] Verify cache hit rate > 60%
- [ ] Verify memory usage < 300MB
- [ ] Check for API timeouts
- [ ] Review search performance

### Weekly Reviews

- [ ] Run full benchmark suite
- [ ] Compare with baseline metrics
- [ ] Review performance trends
- [ ] Check for regressions
- [ ] Update documentation

### Monthly Maintenance

- [ ] Review TTL configurations
- [ ] Optimize cache sizes
- [ ] Clean up old benchmark data
- [ ] Update performance baselines
- [ ] Plan optimization work

## When to Seek Help

**Report issues when**:

- Performance degrades 10%+ suddenly
- Solutions in this guide don't help
- You suspect a Substation bug
- Benchmarks show scores < 0.6

**Where to report**:

- GitHub Issues: <https://github.com/cloudnull/substation/issues>
- Include wiretap logs
- Include benchmark results
- Include environment details

**Information to provide**:

- Substation version
- OpenStack version
- Resource counts (servers, networks, etc.)
- Performance metrics
- Logs with `--wiretap` enabled

## Quick Diagnosis Flowchart

```
Performance Issue
    |
    ├─ Memory High?
    │   ├─ Yes → Press 'c' to purge cache → Reduce TTLs → Increase eviction threshold
    │   └─ No → Continue
    |
    ├─ API Slow?
    │   ├─ Yes → Check OpenStack health → Check network → Enable wiretap
    │   └─ No → Continue
    |
    ├─ Cache Hit Rate Low?
    │   ├─ Yes → Increase TTLs → Reduce eviction → Check for high churn
    │   └─ No → Continue
    |
    ├─ Search Slow?
    │   ├─ Yes → Check service health → Use specific queries → Check cache
    │   └─ No → Continue
    |
    └─ UI Sluggish?
        ├─ Yes → Reduce auto-refresh → Check terminal → Reduce data volume
        └─ No → Report issue (might be a bug)
```

---

**See Also**:

- [Performance Overview](overview.md) - Architecture and components
- [Performance Benchmarks](benchmarks.md) - Metrics and scoring
- [Performance Tuning](tuning.md) - Configuration and optimization
- [Caching Concepts](../concepts/caching.md) - Deep dive into caching

**Remember**: Most performance issues are OpenStack-side, not Substation-side. Always check OpenStack service health first.
