# Search System

Understanding Substation's parallel search architecture.

## Overview

Substation provides two search modes:

1. **Local Search** - Fast filtering within current view
2. **Advanced Search** - Cross-service search across all OpenStack services

## Local Search (Fast Filtering)

### How It Works

Press `/` in any list view:

1. Activates search mode
2. Filters visible items as you type
3. No API calls (purely local)
4. Instant results
5. Press `Esc` to clear

### Features

- **Instant filtering** - Results update as you type
- **Case-insensitive** - "prod" matches "PROD" and "Production"
- **Substring matching** - "web" finds "web-server-01", "webmail", "my-web-app"
- **No network calls** - Works offline with cached data
- **Works in all list views** - Servers, networks, volumes, etc.

### Use Cases

**Quick Resource Location:**

```
In servers list:
Press / -> type "web" -> Shows only servers with "web" in name
```

**Status Filtering:**

```
In servers list:
Press / -> type "error" -> Shows servers in ERROR state
```

**Pattern Matching:**

```
In networks list:
Press / -> type "192.168" -> Shows networks with this IP range
```

### Limitations

- Searches visible fields only (name, ID, status)
- Searches current view only (not cross-service)
- No advanced query syntax (no regex or boolean operators)
- Limited to items already loaded in view

## Advanced Search (Cross-Service)

### How It Works

Use `:search<Enter>` (or `:find<Enter>` or `:z<Enter>`) for advanced search:

1. Opens search interface
2. Type query and press `Enter`
3. Searches **6 services in parallel**:
   - Nova (Compute)
   - Neutron (Networking)
   - Cinder (Storage)
   - Glance (Images)
   - Keystone (Identity)
   - Swift (Object Storage)
4. Results aggregated and displayed
5. Target response time: < 500ms (with caching)

### Parallel Search Architecture

**Sequential Search (Old Way):**

```
Nova (2s) -> Neutron (2s) -> Cinder (2s) -> Glance (2s) -> Keystone (2s) -> Swift (2s)
Total: 12+ seconds
```

**Parallel Search (Substation Way):**

```
Nova (2s) +
Neutron (2s)|- All in parallel
Cinder (2s) |
Glance (2s) |- Results as they come
Keystone (2s)|
Swift (2s)  +
Total: 2 seconds (fastest service) to 5 seconds (timeout)
```

**Performance Gain**: 6x faster (or better)

### Service Priority

Results are ordered by service priority, then relevance:

| Service | Priority | Why This Priority? |
|---------|----------|-------------------|
| Nova (Compute) | 5 (Highest) | Operators search servers most often |
| Neutron (Network) | 4 | Networking searches common |
| Cinder (Storage) | 3 | Volume searches moderate |
| Glance (Images) | 2 | Images searched occasionally |
| Keystone/Swift | 1 (Lowest) | Users/objects searched rarely |

**Why Priority Matters:**

- Results shown in priority order
- Higher priority = appears first in results
- Based on real-world operator workflows

### Search Fields

Each service searches relevant fields:

**Nova (Servers):**

- Name, ID, Status
- Flavor name, Image name
- Host, Tenant ID

**Neutron (Networks):**

- Network name, ID, Status
- Network type, CIDR
- Tenant ID

**Cinder (Volumes):**

- Volume name, ID, Status
- Volume type, Size
- Attached to (server ID)

**Glance (Images):**

- Image name, ID, Status
- Container format, Visibility
- Tags

**Keystone (Users/Projects):**

- User name, ID, Email
- Project name, Domain
- Enabled status

**Swift (Objects):**

- Container name
- Object name
- Metadata

### Relevance Scoring

Results are scored based on match quality:

**Exact Match** (Highest score):

```
Query: "web-server-01"
Match: name == "web-server-01"
Score: 100
```

**Prefix Match** (Medium score):

```
Query: "web"
Match: name starts with "web"
Score: 75
```

**Substring Match** (Lower score):

```
Query: "web"
Match: name contains "web"
Score: 50
```

**Results sorted by**: Priority -> Relevance Score -> Name

### Timeout Handling

**5-Second Timeout** per service:

**Why 5 seconds?**

- If OpenStack can't respond in 5 seconds, it's broken
- Better to show partial results than wait forever
- Operator waiting > 5 seconds = operator rage

**When Timeout Occurs:**

1. Service doesn't respond in 5 seconds
2. Substation moves on
3. Other services still return results
4. User sees partial results with notification
5. Example: "Results from 5 of 6 services (Neutron timed out)"

**This is intentional graceful degradation.**

### Example Queries

**Find Production Resources:**

```
Press z -> type "prod" -> Enter
Results:
- Servers: prod-web-01, prod-db-01, prod-cache-01
- Networks: production-network, prod-dmz
- Volumes: prod-data-vol-01
```

**Find by IP Address:**

```
Press z -> type "192.168.1" -> Enter
Results:
- Networks with this CIDR
- Servers with this IP
- Subnets in this range
```

**Find by State:**

```
Press z -> type "error" -> Enter
Results:
- Servers in ERROR state
- Volumes in error state
- Load balancers with errors
```

**Find by Type:**

```
Press z -> type "ubuntu" -> Enter
Results:
- Images: Ubuntu 22.04, Ubuntu 20.04
- Servers running Ubuntu images
```

## Search Performance

### Cache Integration

Search results are cached:

**First Search:**

```
Query: "production"
Cache: MISS
API Calls: 6 services queried
Time: ~2 seconds
Result: Cached for next time
```

**Repeat Search:**

```
Query: "production"
Cache: HIT
API Calls: 0 (served from cache)
Time: < 100ms
Result: Instant results
```

**Cache Hit Rate for Searches**: ~70%

**Why?** Operators often repeat searches or search for similar terms.

### Performance Metrics

**With Caching (Typical):**

- Average search time: 450ms
- Cache hit rate: 70%
- Instant results for repeated queries

**Without Caching (First Search):**

- Average search time: 1.8s
- All services queried in parallel
- Results as they arrive

**Worst Case (Timeout):**

- Maximum wait: 5 seconds
- Partial results shown
- Timeout services noted

### Optimization

**Query Optimization:**

- Only searches relevant fields per service
- Skips empty or null fields
- Uses indexed fields when available
- Parallel execution prevents bottlenecks

**Result Aggregation:**

- Results streamed as they arrive
- No waiting for all services
- Fastest services shown first
- Slow services don't block

## Search Cache

### Cache Strategy

Search results cached with TTL:

**Search Cache TTL**: 300 seconds (5 minutes)

**Why 5 minutes?**

- Search results fairly stable
- Balance between freshness and performance
- Operators often repeat searches
- Reduces load on OpenStack APIs

### Cache Key

Search cache keys constructed from:

```
search:query:<query-string>:services:<service-list>
```

Example:

```
search:query:production:services:nova,neutron,cinder,glance,keystone,swift
```

### Cache Invalidation

**Automatic:**

- TTL expiration (5 minutes)
- Memory pressure (eviction at 85% usage)

**Manual:**

- Use `:cache-purge<Enter>` (or `:clear-cache<Enter>` or `:cc<Enter>`) to purge ALL caches (including search)

## Best Practices

### When to Use Local Search

Use `/` (local search) when:

- You know which view you need (servers, networks, etc.)
- Searching for visible item in current list
- Need instant results
- Working offline or with cached data

### When to Use Advanced Search

Use `z` (advanced search) when:

- Don't know which service has the resource
- Need to search across all services
- Looking for relationships (which server on which network?)
- Comprehensive resource discovery

### Search Tips

**Be Specific:**

```
Good: "prod-web-01"      (exact match, fast)
Okay: "prod-web"         (prefix match, good)
Slow: "web"              (substring, many results)
```

**Use Filters:**

```
Good: "ubuntu 22.04"     (specific version)
Okay: "ubuntu"           (all ubuntu resources)
```

**Leverage Cache:**

- First search is slower (cache miss)
- Repeat searches are instant (cache hit)
- Vary your queries slightly to benefit from cache

## Troubleshooting

### Slow Search Results

**Symptoms**: Search takes > 2 seconds

**Causes:**

- OpenStack APIs are slow (most common)
- Network latency
- First-time search (cache warming)
- Service overload

**Solutions:**

1. Check OpenStack service health
2. Enable wiretap to see which service is slow:

   ```bash
   substation --wiretap
   ```

3. Review logs for slow services:

   ```bash
   tail -f ~/substation.log | grep "search"
   ```

4. Accept that OpenStack is slow (it happens)

### Incomplete Results

**Symptoms**: "Results from 5 of 6 services" message

**Causes:**

- Service timeout (> 5 seconds)
- Service down or unreachable
- Network issues

**Solutions:**

1. Check which service timed out
2. Verify service availability:

   ```bash
   openstack endpoint list
   ```

3. Check specific service:

   ```bash
   curl https://nova.example.com:8774/
   ```

4. Try search again (might be transient)

### No Results

**Symptoms**: Search returns nothing

**Causes:**

- Typo in query
- Resource doesn't exist
- Wrong project scope
- Service returned empty results

**Solutions:**

1. Check query spelling
2. Try broader search terms
3. Verify you're in correct project
4. Use local search (`/`) to verify data exists

## Implementation Details

### ParallelSearchEngine

Located in `/Sources/Substation/Search/SearchEngine.swift`

**Configuration:**

```swift
SearchEngine(
    maxConcurrentSearches: 6,         // One per service
    searchTimeoutSeconds: 5.0,        // Hard limit
    cacheManager: multiLevelCacheManager
)
```

**Actor-Based Concurrency:**

- Each service search runs in parallel
- Thread-safe result aggregation
- No race conditions (Swift 6 strict concurrency)
- Automatic timeout handling

### Search Query Processing

1. **Query Parsing** - Extract search terms
2. **Service Selection** - Determine which services to query
3. **Parallel Execution** - Launch concurrent searches
4. **Result Collection** - Gather results as they arrive
5. **Scoring** - Apply relevance scoring
6. **Sorting** - Order by priority and score
7. **Caching** - Store results for future searches

### Thread Safety

All search operations are actor-based:

- No locks required
- Concurrent service queries safe
- Result aggregation thread-safe
- Zero data races

---

**Remember**: Search is powerful but use it wisely. Local search (`/`) is instant for current view. Advanced search (`z`) is comprehensive but hits APIs. Choose the right tool for the job.

*Search smart, find fast.*
