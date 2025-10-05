# Performance Benchmarks

Comprehensive benchmarking framework with benchmark categories, scoring, and automated regression detection.

## Benchmark System Overview

**Location**: `/Sources/OSClient/Performance/PerformanceBenchmarkSystem.swift`

The performance benchmark system provides:

- Comprehensive benchmarking across all performance-critical components
- 0.0-1.0 scoring scale for each category
- Automated regression detection (10%+ performance drops)
- Real-time metrics collection
- Performance data export for analysis

## Benchmark Categories

### 1. Cache Performance

**What it measures**:

- Hit rate measurement under load
- Response time analysis (L1/L2/L3 cache)
- Cache statistics and efficiency
- Memory usage patterns

**Targets**:

- Hit rate: 80% (target)
- Response time: < 1ms (L1 cache)
- Eviction rate: < 20% of total entries
- Memory efficiency: < 100MB for 10k resources

**Pass threshold**: 0.8 (80% of target performance)

**Why these targets**:

- 80% hit rate = 80% API call reduction
- 1ms response time = instant from user perspective
- Low eviction rate = cache is right-sized
- Memory efficiency = runs on modest hardware

### 2. Search Performance

**What it measures**:

- Cross-service search speed
- Result relevance scoring accuracy
- Query optimization effectiveness
- Parallel execution efficiency

**Targets**:

- Average search time: < 500ms
- P95 search time: < 1000ms
- Timeout rate: < 5%
- Result relevance: > 90% accuracy

**Pass threshold**: 0.8 (80% of target performance)

**Why these targets**:

- 500ms = acceptable wait for cross-service search
- 1000ms P95 = most searches feel fast
- < 5% timeout = services are mostly healthy
- High relevance = users find what they need

### 3. Memory Management

**What it measures**:

- Allocation success rates
- Cleanup efficiency
- Memory usage tracking
- Pressure handling

**Targets**:

- Memory utilization: < 80% of available
- Cleanup success rate: > 95%
- Memory leak rate: 0%
- Pressure response time: < 100ms

**Pass threshold**: 0.8 (80% of target performance)

**Why these targets**:

- 80% utilization = headroom for spikes
- High cleanup success = no memory leaks
- Zero leak rate = production-ready
- Fast pressure response = prevents OOM

### 4. System Integration

**What it measures**:

- Component interaction efficiency
- Resource usage correlation
- Overall system responsiveness
- End-to-end operation timing

**Targets**:

- API call latency: < 2s (uncached)
- UI responsiveness: < 100ms
- System health score: > 90%
- Integration overhead: < 10%

**Pass threshold**: 0.8 (80% of target performance)

**Why these targets**:

- 2s API latency = acceptable for uncached calls
- 100ms UI = feels instant to users
- 90% health = system is reliable
- Low overhead = efficient integration

### 5. Rendering Performance (TUI Mode)

**What it measures**:

- Frame rate monitoring
- Rendering optimization
- UI responsiveness
- Screen update efficiency

**Targets**:

- Frame rate: 60 FPS (16.7ms per frame)
- UI update latency: < 50ms
- Screen refresh rate: consistent
- Rendering overhead: < 5%

**Pass threshold**: 0.8 (80% of target performance)

**Why these targets**:

- 60 FPS = smooth animations
- 50ms update = feels instant
- Consistent refresh = no jank
- Low overhead = CPU-efficient

## Benchmark Scoring

### Performance Score Calculation

```swift
// From PerformanceBenchmarkSystem.swift:895
private struct PerformanceTargets {
    let cacheHitRate: Double = 0.8          // 80% cache hit rate
    let cacheResponseTime: TimeInterval = 0.001  // 1ms cache response
    let searchResponseTime: TimeInterval = 0.5   // 500ms search response
    let memoryUtilization: Double = 0.8     // 80% memory utilization max
    let systemHealthScore: Double = 0.9     // 90% system health
}
```

**Score calculation**:

- 1.0 = Exceeds target performance
- 0.8-1.0 = Meets or exceeds targets (PASS)
- 0.6-0.8 = Below target but acceptable
- < 0.6 = Performance issue (FAIL)

**Overall score**:

- Weighted average across all categories
- Cache performance: 30% weight (most impactful)
- Search performance: 25% weight
- Memory management: 20% weight
- System integration: 15% weight
- Rendering performance: 10% weight

### Regression Detection

**Automatic alerts trigger when**:

- Performance drops 10%+ from baseline
- Score falls below 0.8 threshold
- Timeout rate increases significantly
- Memory usage spikes unexpectedly

**Baseline establishment**:

- Run benchmarks on clean install
- Average 5 benchmark runs
- Establish per-category baselines
- Track trends over time

## Running Benchmarks

### Full Benchmark Suite

```swift
let benchmarkSystem = PerformanceBenchmarkSystem(...)
let report = await benchmarkSystem.runFullBenchmarkSuite()

print("Overall Score: \(report.overallScore)")
print("Cache Performance: \(report.cacheScore)")
print("Search Performance: \(report.searchScore)")
```

**When to run**:

- After code changes affecting performance
- Before releases (regression check)
- During production troubleshooting
- Weekly for trend analysis

### Specific Benchmarks

```swift
// Run cache benchmark only
let cacheResults = await benchmarkSystem.runBenchmark(.cache)

// Run search benchmark only
let searchResults = await benchmarkSystem.runBenchmark(.search)

// Run memory benchmark only
let memoryResults = await benchmarkSystem.runBenchmark(.memory)
```

**When to run specific benchmarks**:

- Cache: After changing TTL configurations
- Search: After modifying search algorithms
- Memory: When investigating memory issues
- System: After architectural changes

### Benchmark Scheduling

Automated benchmark execution:

- **Cache benchmarks**: Every 5 minutes (lightweight)
- **Memory benchmarks**: Every 3 minutes (critical for stability)
- **Search benchmarks**: Every 10 minutes (more expensive)
- **System integration**: Every 15 minutes (comprehensive)
- **Full suite**: On-demand or nightly

## Real-Time Metrics

### getCurrentPerformanceMetrics() API

```swift
public struct RealTimeMetrics: Sendable {
    public let timestamp: Date
    public let cacheHitRate: Double           // Current cache hit rate
    public let memoryUtilization: Double      // Memory usage percentage
    public let systemHealthScore: Double      // Overall system health (0-1)
    public let averageResponseTime: TimeInterval // Average API response time
    public let renderingFPS: Double           // Current rendering frame rate
    public let totalApiCalls: Int            // Total API calls made
}
```

**Usage**:

```swift
let metrics = await benchmarkSystem.getCurrentPerformanceMetrics()

print("Cache Hit Rate: \(metrics.cacheHitRate * 100)%")
print("Memory Usage: \(metrics.memoryUtilization * 100)%")
print("Health Score: \(metrics.systemHealthScore * 100)%")
```

### Performance Alerts

Automatic alerts trigger when:

- **Cache hit rate** < 60%
- **Memory utilization** > 85%
- **Average response time** > 2 seconds
- **System health score** < 70%
- **Rendering FPS** < 30 (half target)

## Benchmark Reports

### Comprehensive Report Structure

```swift
public struct BenchmarkReport {
    public let timestamp: Date
    public let overallScore: Double
    public let cacheScore: Double
    public let searchScore: Double
    public let memoryScore: Double
    public let systemScore: Double
    public let renderingScore: Double
    public let detailedMetrics: [String: Double]
    public let recommendations: [String]
    public let regressions: [RegressionAlert]
}
```

**Report includes**:

- **Performance scores**: 0.0-1.0 scale for each category
- **Detailed metrics**: Response times, hit rates, memory usage
- **Recommendations**: Specific optimization suggestions
- **Trend analysis**: Performance changes over time
- **Regression alerts**: Automatic performance regression detection

### Sample Benchmark Report

```
=== Performance Benchmark Report ===
Timestamp: 2025-10-05 14:23:45

Overall Score: 0.87 (PASS)

Category Scores:
  Cache Performance:     0.92 (EXCELLENT)
  Search Performance:    0.85 (GOOD)
  Memory Management:     0.88 (GOOD)
  System Integration:    0.84 (GOOD)
  Rendering Performance: 0.86 (GOOD)

Detailed Metrics:
  Cache Hit Rate:        89.2%
  Cache Response Time:   0.8ms
  Search Time (avg):     450ms
  Search Time (p95):     890ms
  Memory Utilization:    72%
  System Health:         93%
  Rendering FPS:         58.4

Recommendations:
  - Cache performance excellent (89% hit rate)
  - Search performance within targets
  - Memory usage healthy
  - No regressions detected

Status: All systems nominal
```

## Performance Data Export

### Export API

```swift
// Export performance data for analysis
let performanceData = await benchmarkSystem.exportPerformanceData()

// Includes:
// - Trends over time
// - Recent benchmark results
// - Regression detection data
// - Historical baselines
```

**Export formats**:

- JSON (for programmatic analysis)
- CSV (for spreadsheet import)
- Structured logs (for monitoring systems)

**What's exported**:

- All benchmark scores (time-series)
- Detailed metrics per benchmark
- Regression events
- Alert history
- System configuration at time of benchmark

## Interpreting Benchmark Results

### Excellent Performance (Score: 0.9-1.0)

**What it means**:

- System performing above targets
- No optimization needed
- Celebrate good architecture

**Actions**:

- Document current configuration
- Establish as baseline
- Monitor for regressions

### Good Performance (Score: 0.8-0.9)

**What it means**:

- System meeting targets
- Minor optimization opportunities
- Production-ready

**Actions**:

- Monitor trends
- Consider minor tuning
- Track for future improvements

### Acceptable Performance (Score: 0.6-0.8)

**What it means**:

- System below targets
- Optimization recommended
- Still functional but not optimal

**Actions**:

- Review configuration
- Identify bottlenecks
- Plan optimization work

### Poor Performance (Score: < 0.6)

**What it means**:

- System significantly below targets
- Performance issues present
- Immediate action required

**Actions**:

- Investigate immediately
- Check for regressions
- Review recent changes
- See [Troubleshooting Guide](troubleshooting.md)

## Benchmark Best Practices

### 1. Consistent Environment

- Run benchmarks on consistent hardware
- Minimize background processes
- Use same OpenStack environment
- Avoid peak usage times

### 2. Baseline Establishment

- Run 5+ benchmarks to establish baseline
- Average scores for consistency
- Document environment configuration
- Update baseline quarterly

### 3. Regular Monitoring

- Schedule automated benchmarks
- Review trends weekly
- Investigate anomalies immediately
- Track improvements over time

### 4. Regression Response

- Investigate 10%+ drops immediately
- Compare with recent code changes
- Rollback if necessary
- Document root cause

---

**See Also**:

- [Performance Overview](overview.md) - Architecture and key components
- [Performance Tuning](tuning.md) - Optimization strategies
- [Troubleshooting](troubleshooting.md) - Performance issue diagnosis

**Note**: All benchmark targets are based on production testing with 10K+ resources. Adjust targets based on your specific environment and requirements.
