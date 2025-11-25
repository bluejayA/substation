# Search System

Finding one server among 50,000 shouldn't require a treasure map.

## Overview

We built Substation's search system around a simple truth: operators don't always know where their resources are. Is that production database in Nova? Did someone tag it in Neutron metadata? We provide two search modes because sometimes you know exactly where to look, and sometimes you need to cast a wide net.

Local search (press `/`) filters what's already on your screen. Advanced search (press `z`) asks every OpenStack service simultaneously whether they've seen what you're looking for. Both modes exist because speed matters differently depending on whether you're browsing or hunting.

## Local Search (Fast Filtering)

Press `/` in any list view and start typing. The search activates instantly, filtering visible items as you type with no API calls involved. Everything happens locally against data already loaded in your view. Press `Esc` to clear the filter and return to the full list.

This is pure client-side filtering with instant results. It's case-insensitive, so "prod" matches "PROD" and "Production" equally well. Substring matching means "web" will find "web-server-01", "webmail", and "my-web-app" all at once. Since there are no network calls involved, this works perfectly fine with cached data or even offline.

You can use local search in any list view: servers, networks, volumes, images, or anything else displayed as a list. It's the fastest way to narrow down what you're looking at when you already know which service you're browsing.

### Use Cases

Need to find your web servers in a list of 500 instances? In the servers list, press `/`, type "web", and you'll see only servers with "web" in their name. Hunting for error states? Press `/`, type "error", and watch the list collapse to show only servers in ERROR state.

Pattern matching works too. In your networks list, press `/` and type "192.168" to show only networks using that IP range. The search examines whatever fields are visible in the current view.

```
In servers list:
Press / -> type "web" -> Shows only servers with "web" in name

In servers list:
Press / -> type "error" -> Shows servers in ERROR state

In networks list:
Press / -> type "192.168" -> Shows networks with this IP range
```

### Limitations

Local search is fast precisely because it's limited. We search only visible fields like name, ID, and status. We search only the current view, not across services. There's no advanced query syntax, no regex, no boolean operators. We filter what's already loaded, nothing more.

This isn't a weakness -- it's intentional design. Sometimes you don't need the sledgehammer.

## Advanced Search (Cross-Service)

When you genuinely have no idea which service contains what you're looking for, use advanced search. Type `:search` (or `:find` or just `:z`) and press Enter to open the search interface. Type your query, press Enter again, and watch as we simultaneously ask six OpenStack services whether they know anything about your search term.

We query Nova (Compute), Neutron (Networking), Cinder (Storage), Glance (Images), Keystone (Identity), and Swift (Object Storage) in parallel. Results aggregate as they arrive, with a target response time under 500ms when caching is warm. This isn't magic -- it's just refusing to wait for slow services to hold up fast ones.

### Parallel Search Architecture

The old way of searching was sequential torture. Query Nova, wait 2 seconds. Query Neutron, wait 2 more. Continue through all six services and you've burned 12 seconds of your life. Operators who deal with production incidents don't have 12 seconds to waste.

We run all six service queries simultaneously instead:

```
Sequential Search (Old Way):
Nova (2s) -> Neutron (2s) -> Cinder (2s) -> Glance (2s) -> Keystone (2s) -> Swift (2s)
Total: 12+ seconds

Parallel Search (Substation Way):
Nova (2s) +
Neutron (2s)|- All in parallel
Cinder (2s) |
Glance (2s) |- Results as they come
Keystone (2s)|
Swift (2s)  +
Total: 2 seconds (fastest service) to 5 seconds (timeout)
```

Performance gain: 6x faster, or better. The slowest service no longer holds everyone else hostage.

### Service Priority

Not all OpenStack services are equally important when you're searching. We order results by service priority, then by relevance within each service. Nova (Compute) gets priority 5 because operators search for servers more than anything else. Neutron (Network) gets priority 4 since networking searches are common. Cinder (Storage) sits at priority 3 for moderate volume searches. Glance (Images) gets priority 2 because you search for images occasionally, not constantly. Keystone and Swift both get priority 1 since users and objects are the least frequently searched resources.

| Service | Priority | Why This Priority? |
|---------|----------|-------------------|
| Nova (Compute) | 5 (Highest) | Operators search servers most often |
| Neutron (Network) | 4 | Networking searches common |
| Cinder (Storage) | 3 | Volume searches moderate |
| Glance (Images) | 2 | Images searched occasionally |
| Keystone/Swift | 1 (Lowest) | Users/objects searched rarely |

Priority matters because results appear in priority order. Higher priority means your matches show up first, based on real-world operator workflows we've observed.

### Search Fields

Each service searches fields relevant to its domain. Nova searches server name, ID, status, flavor name, image name, host, and tenant ID. Neutron examines network name, ID, status, network type, CIDR, and tenant ID. Cinder looks at volume name, ID, status, volume type, size, and which server the volume is attached to.

Glance searches image name, ID, status, container format, visibility, and tags. Keystone checks user name, ID, email, project name, domain, and enabled status. Swift searches container names, object names, and metadata.

We don't search every field blindly. We skip empty or null fields, focus on indexed fields when available, and only examine data that makes sense for each service. This optimization prevents unnecessary work and speeds up results.

### Relevance Scoring

Match quality matters. An exact match scores higher than a prefix match, which scores higher than a substring match. If you search for "web-server-01" and we find a resource named exactly "web-server-01", that gets a score of 100. If we find "web-anything" where the name starts with "web", that scores 75. If we find "my-web-app" where "web" appears in the middle, that scores 50.

```
Exact Match (Highest score):
Query: "web-server-01"
Match: name == "web-server-01"
Score: 100

Prefix Match (Medium score):
Query: "web"
Match: name starts with "web"
Score: 75

Substring Match (Lower score):
Query: "web"
Match: name contains "web"
Score: 50
```

Results sort by priority first, then relevance score, then name. This means high-priority exact matches appear before low-priority exact matches, which appear before high-priority substring matches.

### Timeout Handling

We enforce a 5-second timeout per service. Why 5 seconds? Because if OpenStack can't respond in 5 seconds, something is seriously broken. Waiting longer won't help. We'd rather show you partial results than make you wait forever while a broken service fails to respond.

When a service times out, we move on. Other services still return their results. You see what we found with a notification explaining which service didn't respond. For example: "Results from 5 of 6 services (Neutron timed out)". This is intentional graceful degradation -- better to get most of your answer quickly than none of your answer slowly.

An operator waiting more than 5 seconds for search results is an operator approaching rage. We respect your time.

### Example Queries

Search for "prod" to find all production resources across every service. You'll get servers like prod-web-01, prod-db-01, prod-cache-01, networks like production-network and prod-dmz, and volumes like prod-data-vol-01.

```
Press z -> type "prod" -> Enter
Results:
- Servers: prod-web-01, prod-db-01, prod-cache-01
- Networks: production-network, prod-dmz
- Volumes: prod-data-vol-01
```

Search for an IP address like "192.168.1" to find networks with that CIDR, servers with that IP, and subnets in that range. Search for "error" to surface servers in ERROR state, volumes in error state, and load balancers with errors. Search for "ubuntu" to find Ubuntu images and servers running Ubuntu images.

```
Find by IP Address:
Press z -> type "192.168.1" -> Enter
Results:
- Networks with this CIDR
- Servers with this IP
- Subnets in this range

Find by State:
Press z -> type "error" -> Enter
Results:
- Servers in ERROR state
- Volumes in error state
- Load balancers with errors

Find by Type:
Press z -> type "ubuntu" -> Enter
Results:
- Images: Ubuntu 22.04, Ubuntu 20.04
- Servers running Ubuntu images
```

## Search Performance

### Cache Integration

We cache search results because operators often repeat searches or search for similar terms. Your first search for "production" misses the cache, queries all six services, takes about 2 seconds, then gets cached for next time. Your second search for "production" hits the cache, makes zero API calls, and returns results in under 100ms.

```
First Search:
Query: "production"
Cache: MISS
API Calls: 6 services queried
Time: ~2 seconds
Result: Cached for next time

Repeat Search:
Query: "production"
Cache: HIT
API Calls: 0 (served from cache)
Time: < 100ms
Result: Instant results
```

Our cache hit rate for searches runs around 70%. This isn't surprising -- operators frequently search for the same resources, especially during incident response when you're repeatedly checking the same failing server.

### Performance Metrics

With caching enabled (typical case), average search time is 450ms with a 70% cache hit rate. Repeated queries return instantly. Without caching (first search or cache miss), average search time is 1.8 seconds with all services queried in parallel and results arriving as they complete. Worst case with timeout: 5 seconds maximum wait, partial results shown, timeout services noted.

Why this matters: when you're staring at a production outage, every second counts. We optimize aggressively because your time is valuable.

### Optimization

We query only relevant fields per service, skip empty or null fields, use indexed fields when available, and execute everything in parallel to prevent bottlenecks. Results stream as they arrive rather than waiting for all services to complete. The fastest services show first, and slow services don't block anything.

This result aggregation strategy means you start seeing matches almost immediately. No waiting for the slowest service to finish before displaying anything.

## Search Cache

### Cache Strategy

Search results cache with a 5-minute TTL. This balances freshness with performance -- search results are fairly stable over short periods, operators often repeat searches, and reducing load on OpenStack APIs benefits everyone. If you need fresher data, the cache will expire automatically after 5 minutes.

Search cache keys are constructed from the query string and service list:

```
search:query:<query-string>:services:<service-list>

Example:
search:query:production:services:nova,neutron,cinder,glance,keystone,swift
```

### Cache Invalidation

The cache invalidates automatically on TTL expiration (5 minutes) and when memory pressure triggers eviction at 85% usage. You can manually purge all caches including search using `:cache-purge` (or `:clear-cache` or `:cc`).

## Best Practices

### When to Use Local Search

Use `/` for local search when you already know which view you need (servers, networks, etc.), when you're searching for a visible item in the current list, when you need instant results, or when working offline with cached data. Local search is zero-latency filtering of what's already on screen.

### When to Use Advanced Search

Use `z` for advanced search when you don't know which service has the resource, when you need to search across all services, when looking for relationships (which server on which network?), or when doing comprehensive resource discovery. Advanced search trades a bit of latency for complete coverage.

### Search Tips

Be specific with your queries. An exact match like "prod-web-01" is fast and precise. A prefix match like "prod-web" is good. A vague substring like "web" returns many results and runs slower.

```
Good: "prod-web-01"      (exact match, fast)
Okay: "prod-web"         (prefix match, good)
Slow: "web"              (substring, many results)
```

Use filters to narrow scope. Searching for "ubuntu 22.04" (specific version) is better than searching for "ubuntu" (all ubuntu resources). Your first search will be slower due to cache miss, but repeat searches are instant due to cache hits. Vary your queries slightly to benefit from the cache without defeating it.

## Troubleshooting

### Slow Search Results

If search takes longer than 2 seconds, OpenStack APIs are probably slow (most common cause), or you're experiencing network latency, warming a cold cache, or hitting overloaded services.

Check OpenStack service health first. Enable wiretap to see which service is slow:

```bash
substation --wiretap
```

Review logs for slow services:

```bash
tail -f ~/substation.log | grep "search"
```

Sometimes you just have to accept that OpenStack is slow. It happens. Production clouds under load aren't always responsive. We've already done everything we can on the client side -- parallel queries, aggressive caching, reasonable timeouts. If the APIs are slow, there's only so much we can do.

### Incomplete Results

If you see "Results from 5 of 6 services" messages, a service timed out (took more than 5 seconds), is down or unreachable, or you're experiencing network issues.

Check which service timed out, then verify service availability:

```bash
openstack endpoint list
```

Check the specific service:

```bash
curl https://nova.example.com:8774/
```

Try the search again -- it might be transient. Distributed systems have transient failures. Sometimes retrying just works.

### No Results

If search returns nothing, check for typos in your query, verify the resource actually exists, confirm you're in the correct project scope, or consider whether the service returned empty results legitimately.

Check query spelling first (we've all been there). Try broader search terms. Verify you're in the correct project -- wrong project scope is a common gotcha. Use local search (`/`) to verify data exists in the view you're currently browsing.

## Implementation Details

### ParallelSearchEngine

Our search engine lives in `/Sources/Substation/Search/SearchEngine.swift` and configures for maximum concurrency:

```swift
SearchEngine(
    maxConcurrentSearches: 6,         // One per service
    searchTimeoutSeconds: 5.0,        // Hard limit
    cacheManager: multiLevelCacheManager
)
```

We use actor-based concurrency so each service search runs in parallel with thread-safe result aggregation, zero race conditions (thanks to Swift 6 strict concurrency), and automatic timeout handling. No locks required. Concurrent service queries are safe. Result aggregation is thread-safe. Zero data races.

### Search Query Processing

Query processing follows a clear pipeline: parse the search terms, select which services to query, execute searches in parallel, gather results as they arrive, apply relevance scoring, sort by priority and score, then cache results for future searches.

This pipeline ensures consistent behavior while maximizing performance at each stage.

### Thread Safety

All search operations use Swift actors, which means no manual locking required, concurrent service queries stay safe, result aggregation remains thread-safe, and we achieve zero data races. Swift 6's strict concurrency checking verifies this at compile time, not runtime.

---

**Remember**: Search is powerful but use it wisely. Local search (`/`) is instant for the current view. Advanced search (`z`) is comprehensive but hits APIs. Choose the right tool for the job.

*Search smart, find fast.*
