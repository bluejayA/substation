# Technology Stack

This document details the core technologies, dependencies, and development tools that power Substation.

## Core Technologies (The Good Stuff)

### Language: Swift 6.1

We chose Swift 6.1 for Substation, and we're not looking back. This wasn't a trendy decision or a gamble on unproven technology. Swift delivers actor-based concurrency with compile-time thread safety guarantees, memory safety without garbage collection pauses, and native cross-platform support for macOS and Linux. The modern language features like async/await and Result types eliminate entire classes of bugs that plague traditional systems programming languages. When you're building infrastructure tooling that needs to be fast, safe, and maintainable, Swift 6 gives you all three without compromise.

**Swift 6 Strict Concurrency:**

Substation enforces Swift 6 strict concurrency mode with a **zero-warning build standard**. We treat warnings as errors because warnings become production bugs. No exceptions, no excuses. Every concurrency warning is a potential race condition. Every memory warning is a potential leak or crash. Every type warning is a runtime error waiting to happen.

```swift
// From Package.swift
swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency")
]
```

This eliminates race conditions at compile-time, prevents data races through actor isolation, and guarantees thread safety before your code ever runs. The compiler does the hard work so you don't have to debug threading issues at 3 AM in production.

**Code Example:**

```swift
// All shared state protected by actors
public actor CoreTokenManager {
    private var encryptedToken: Data?  // Protected by actor

    public func getValidToken() async throws -> String {
        // Automatic serialization by Swift runtime
    }
}

// UI is MainActor
@MainActor final class TUI {
    // All UI operations on main thread
}
```

### Concurrency: Swift Actors & async/await

We built Substation on Swift's actor model because it eliminates entire categories of concurrency bugs that have haunted systems programming for decades. No locks, no mutexes, no semaphores, no race conditions. The compiler guarantees thread safety, and the runtime handles all the coordination.

Our architecture uses three actor types: MainActor for UI updates and SwiftNCurses rendering, Service Actors for API calls and OpenStack client operations, and Worker Actors for background tasks like search, benchmarks, and telemetry. Each actor gets automatic serialization and thread management from the Swift runtime. Clean async/await syntax means the code reads like synchronous code but performs like highly optimized concurrent code.

**Example:**

```swift
// Service class for API calls
@MainActor
public actor OpenStackClientCore {
    private let tokenManager: CoreTokenManager

    public func request<T: Decodable>(...) async throws -> T {
        let token = try await ensureAuthenticated()
        // Thread-safe by design
    }
}
```

### UI Framework: Custom SwiftNCurses

We built our own terminal UI framework from scratch because the alternatives didn't exist. Existing Swift terminal libraries were either non-existent, incomplete, not cross-platform, or couldn't hit our performance targets. We needed 60fps rendering (16.7ms frame time), cross-platform support for macOS and Linux, and a SwiftUI-like declarative syntax that made building complex UIs actually pleasant.

SwiftNCurses delivers all of this. Built directly on NCurses with no external UI dependencies, it uses differential rendering to update only changed cells and double buffering to eliminate flicker. Typical frame times run 5-10ms, well under our 16.7ms target. The declarative syntax feels natural if you've used SwiftUI, but it runs in your terminal.

**Code Example:**

```swift
List(items: servers) { server in
    HStack {
        Text(server.name).bold()
        Spacer()
        Text(server.status).color(statusColor(server.status))
    }
}
```

### Networking: URLSession with async/await

URLSession with async/await gives us HTTP/2 support when OpenStack endpoints support it, connection pooling for performance, and clean integration with Swift's concurrency model. We implemented custom retry logic with exponential backoff and three attempts per request because network failures in production are inevitable.

**Retry Logic:**

```swift
// Automatic retry with exponential backoff
func requestWithRetry<T: Decodable>(...) async throws -> T {
    var attempt = 0
    while attempt < 3 {
        do {
            return try await performRequest()
        } catch {
            attempt += 1
            if attempt < 3 {
                try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(attempt)) * 1_000_000_000))
            } else {
                throw error
            }
        }
    }
}
```

### Serialization: Codable with Custom Coders

OpenStack's JSON responses are... interesting. Multiple date formats across different services, inconsistent snake_case to camelCase conventions, and occasionally malformed data. We use Swift's Codable with custom decoders for type-safe handling that fails fast on schema changes but gracefully handles the quirks we've learned to expect.

**Example:**

```swift
struct Server: Codable {
    let id: String
    let name: String
    let status: String
    let created: Date

    enum CodingKeys: String, CodingKey {
        case id, name, status
        case created = "created_at"  // Handle snake_case
    }
}
```

### Logging: Structured Logging with Levels

Structured logging with proper levels (Debug, Info, Warning, Error) gives us contextual information when debugging production issues without drowning in noise during normal operation. Wiretap mode logs every API call with full request and response details when you need to see exactly what's happening on the wire.

**Contextual Logging:**

```swift
logger.debug("Cache hit for servers", metadata: [
    "cache_level": "L1",
    "response_time_ms": "0.8",
    "ttl_remaining": "108"
])
```

**Wiretap Mode** (optional):

```bash
# Enable detailed API logging
substation --cloud mycloud --wiretap

# Logs ALL API calls (gets very verbose)
tail -f ~/substation.log
```

### Package Management: Swift Package Manager

Swift Package Manager is simple and works everywhere. No CocoaPods, no Carthage, no NPM-style dependency hell. Reproducible builds, fast incremental compilation, and zero configuration files beyond Package.swift. We keep external dependencies minimal because every dependency is a maintenance burden and a potential security risk.

## Package Dependencies

### External Dependencies (Curated)

We run with exactly **one** external dependency. That's not an accident. Every dependency is technical debt, so we only take on debt that pays real dividends. Here's what made the cut:

#### swift-crypto (Apple-maintained)

```swift
.package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
```

**Purpose**: AES-256-GCM encryption for credentials

We use swift-crypto because it's Apple-maintained and audited, works cross-platform on macOS and Linux, and provides authenticated encryption that prevents padding oracle attacks. This replaced weak XOR encryption on Linux after a security audit in October 2025. Storing OpenStack credentials securely isn't optional.

### System Dependencies

#### Foundation (Swift Standard Library)

Foundation ships with Swift, no separate installation needed. We use it for everything from data types (String, Array, Dictionary) to date handling, file I/O, URL management, and JSON encoding/decoding. It's battle-tested and cross-platform.

#### NCurses (Terminal Rendering)

NCurses comes pre-installed on macOS. On Linux you'll need to install it explicitly, but it's available in every package manager we've tested.

**Linux (Ubuntu/Debian):**

```bash
sudo apt install -y libncurses6 libncurses-dev
```

**Linux (RHEL/CentOS/Fedora):**

```bash
sudo dnf install -y ncurses-libs ncurses-devel
```

NCurses handles terminal control (cursor movement, colors, attributes), input handling (keyboard, mouse), and screen management (resize, refresh). It's the foundation that SwiftNCurses builds on.

## Platform Support

### macOS: Native Support with Darwin APIs

**Supported Versions**: macOS 13+ (Ventura and later)

macOS is a first-class platform with native Keychain integration available (though not used in current implementation), autoreleasepool for memory management optimization, and NCurses pre-installed with the system.

**Memory Management:**

```swift
#if os(macOS)
autoreleasepool {
    // Memory-intensive operations
    // Auto-released at end of scope
}
#endif
```

### Linux: Full Compatibility with Glibc

**Supported Distributions**: Ubuntu 20.04+, Debian 11+, RHEL 8+, CentOS 8+, Fedora 35+

Linux support is production-ready and well-tested. We use file-based credential storage since there's no keychain equivalent, handle memory management manually without autoreleasepool, and require explicit NCurses dev header installation. The experience is identical to macOS for end users.

**Timer Implementation:**

```swift
#if os(Linux)
// Use Glibc timer APIs
import Glibc
#else
// Use Darwin timer APIs
import Darwin
#endif
```

### CrossPlatformTimer Package

Different timer APIs on macOS (Dispatch) and Linux (Glibc) meant we needed abstraction. CrossPlatformTimer provides the same interface across platforms, eliminates conditional compilation in application code, and can be tested in isolation. One codebase, two platforms, zero headaches.

**Implementation:**

```swift
// Darwin (macOS)
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS)
import Dispatch
func createTimer(interval: Double, repeats: Bool, handler: @escaping () -> Void) -> Any {
    return DispatchSourceTimer(...)
}
#endif

// Linux
#if os(Linux)
import Glibc
func createTimer(interval: Double, repeats: Bool, handler: @escaping () -> Void) -> Any {
    // Glibc timer implementation
}
#endif
```

### Windows Support: Not Yet

**Status**: Not supported

We know this is frustrating. We're not ignoring Windows users. The reality is that Windows terminal APIs are fundamentally different from NCurses, Swift on Windows has limited server-side support, and building a proper cross-platform terminal abstraction for Windows would require significant engineering effort. We'd rather focus on making macOS and Linux rock solid than ship half-baked Windows support.

**Workaround for Windows Users:**

Use WSL2 (Windows Subsystem for Linux). It's actually quite good:

```bash
# Install WSL2 and Ubuntu
wsl --install

# Inside WSL2
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
```

**Future**: If you're a Windows expert who understands both the Windows terminal APIs and Swift's concurrency model, PRs are genuinely welcome. We'd love native Windows support, but we won't ship it until it meets the same quality bar as our macOS and Linux support.

## Trade-offs and Limitations

We believe in being honest about what Swift doesn't do well. Here's what you're signing up for:

**Compile Times**: Swift's type system and concurrency checking are thorough, which means compile times can be slower than Go or Rust for large projects. Clean builds take 30-45 seconds on modern hardware. We've optimized where we can, but physics is physics.

**Ecosystem Size**: Swift's server-side ecosystem is smaller than Node, Python, or Go. Finding libraries for niche use cases can be challenging. This is why we built our own terminal UI framework.

**Cross-Platform Challenges**: Swift is genuinely cross-platform for macOS and Linux, but platform differences still surface in areas like timers, file systems, and security APIs. We handle these with conditional compilation, but it adds complexity.

**Windows Support**: As mentioned above, Windows is a second-class citizen in the Swift ecosystem. WSL2 works, but it's not native.

**Learning Curve**: Swift 6's strict concurrency is powerful but takes time to internalize. If you're used to Go's goroutines or Python's threads, actors will feel different. The compiler errors can be cryptic until you learn the patterns.

These trade-offs are real, but for Substation they're worth it. We get compile-time safety, zero race conditions, excellent performance, and code that's actually maintainable. We'll take slower compile times over debugging threading issues in production any day.

## Development Tools

### Build System: Swift Package Manager

Swift Package Manager enforces zero-warning builds, strict concurrency checking in Swift 6 mode, and cross-platform build support for macOS and Linux.

**Commands:**

```bash
# Release build (optimized)
~/.swiftly/bin/swift build -c release

# Debug build (with symbols)
~/.swiftly/bin/swift build

# Clean build
~/.swiftly/bin/swift package clean

# Run tests
~/.swiftly/bin/swift test
```

**Build Time** (on modern hardware): macOS M-series chips complete clean builds in around 30 seconds, Linux with recent CPUs in about 45 seconds. Incremental builds typically finish in 1-5 seconds.

### Testing: XCTest with Comprehensive Test Suites

**Test Structure:**

```
/Tests/
  OSClientTests/        # OpenStack client tests
  SubstationTests/      # Application tests
  TUITests/             # UI framework tests
```

We write unit tests for individual components, integration tests for service interactions, and performance tests for benchmarking and profiling. Tests run on every commit in CI and locally before any PR gets merged.

**Running Tests:**

```bash
# Run all tests
~/.swiftly/bin/swift test

# Run specific test
~/.swiftly/bin/swift test --filter ServerTests

# Generate code coverage
~/.swiftly/bin/swift test --enable-code-coverage
```

### Documentation: DocC and Markdown

**Code Documentation** (DocC):

```swift
/// Retrieves a server by ID.
///
/// - Parameter id: The unique identifier of the server
/// - Returns: The server object if found
/// - Throws: `OpenStackError.notFound` if server doesn't exist
public func getServer(id: String) async throws -> Server {
    // Implementation
}
```

**User Documentation** (Markdown): Located in `/docs/`, built with standard Markdown, includes architecture diagrams using Mermaid for visual documentation.

### CI/CD: Cross-Platform Build Verification

Every push and pull request triggers automated checks: build verification on macOS and Linux, test execution across all suites, zero-warning verification (seriously), code coverage tracking, and security scanning for vulnerabilities.

**GitHub Actions Example:**

```yaml
name: Build and Test
on: [push, pull_request]
jobs:
  build:
    strategy:
      matrix:
        os: [macos-latest, ubuntu-latest]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/checkout@v3
      - name: Install Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: "6.1"
      - name: Build
        run: swift build -c release
      - name: Test
        run: swift test
```

### Performance: Built-in Telemetry and Monitoring

**Real-Time Metrics** (`/Sources/OSClient/Enterprise/Telemetry/`): We track cache hit rates (L1/L2/L3), API response times (p50, p95, p99), memory usage (RSS, cache size), and search performance (query time, result count). Automatic benchmarking runs every 5 minutes in the background, tracks performance over time, and alerts on 10%+ degradation.

**Performance Dashboard:**

Use `:health<Enter>` (or `:h<Enter>`) in Substation to view live metrics. We target 80%+ cache hit rate, sub-2s p95 API response times, under 400MB typical memory usage, and under 500ms average search latency.

## Version Management

### Swiftly (Recommended)

Swiftly is the official Swift version manager from the Swift Server Working Group. It manages multiple Swift versions, makes switching between versions trivial, works consistently across macOS and Linux, and has official support from the Swift project.

**Installation:**

```bash
# Install Swiftly
curl -L https://swift-server.github.io/swiftly/swiftly-install.sh | bash

# Install Swift 6.1
swiftly install "6.1"

# Activate Swift 6.1
swiftly use "6.1"

# Verify
~/.swiftly/bin/swift --version
# Should show: Swift version 6.1 or later
```

## Related Documentation

For more details on the architecture:

- **[Architecture Overview](./overview.md)** - High-level design principles
- **[Components](./components.md)** - Detailed component architecture
- **[Performance](../performance/index.md)** - Performance benchmarking
- **[Security](../concepts/security.md)** - Security implementation

---

**Note**: This technology stack documentation is based on the current implementation. All technologies mentioned are actively used in production.
