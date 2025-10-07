# Technology Stack

This document details the core technologies, dependencies, and development tools that power Substation.

## Core Technologies (The Good Stuff)

### Language: Swift 6.1

**Why Swift?**

- **Actor-based concurrency** - No race conditions by design
- **Compile-time thread safety** - Guaranteed by Swift 6 strict concurrency
- **Memory safety** - No garbage collection, no use-after-free
- **Cross-platform** - Native support for macOS and Linux
- **Modern language features** - Async/await, Result types, protocols

**Swift 6 Strict Concurrency:**

Substation enforces Swift 6 strict concurrency mode with a **zero-warning build standard**:

```swift
// From Package.swift
swiftSettings: [
    .enableExperimentalFeature("StrictConcurrency")
]
```

This eliminates:

- Race conditions (compile-time prevention)
- Data races (actor isolation)
- Thread safety bugs (guaranteed by compiler)

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

**Actor-Based Architecture:**

- **MainActor** - UI updates (SwiftTUI rendering)
- **Service Actors** - API calls (OpenStack client operations)
- **Worker Actors** - Background tasks (search, benchmarks, telemetry)

**Benefits:**

- Zero race conditions (guaranteed by compiler)
- No locks, no mutexes, no semaphores
- Automatic thread management
- Clean async/await syntax

**Example:**

```swift
// Service actor for API calls
public actor OpenStackClientCore {
    private let tokenManager: CoreTokenManager

    public func request<T: Decodable>(...) async throws -> T {
        let token = try await ensureAuthenticated()
        // Thread-safe by design
    }
}
```

### UI Framework: Custom SwiftTUI

**Built from Scratch on NCurses:**

- No external UI dependencies
- 60fps rendering target (16.7ms frame time)
- SwiftUI-like declarative syntax (but for terminals)
- Cross-platform (macOS and Linux)

**Why Custom Framework?**

Existing terminal UI libraries for Swift were either:

- Non-existent
- Incomplete
- Not cross-platform
- Not performant enough

**Performance:**

- Target: 16.7ms/frame (60fps)
- Typical: 5-10ms/frame
- Differential rendering (only changed cells)
- Double buffering (no flicker)

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

**Features:**

- HTTP/2 support (when OpenStack endpoints support it)
- Connection pooling (reuse connections for performance)
- Custom retry logic (exponential backoff, 3 attempts)
- Async/await adapters for clean code

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

**OpenStack JSON Handling:**

- Type-safe decoding (fail fast on schema changes)
- Custom date formatters (OpenStack uses 3+ different formats)
- Graceful handling of optional fields
- Error recovery for malformed responses

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

**Log Levels:**

- **Debug** - Detailed diagnostic information
- **Info** - General informational messages
- **Warning** - Warning messages (potential issues)
- **Error** - Error messages (actual problems)

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

**Minimal External Dependencies**:

- Simple, works everywhere
- No CocoaPods, no Carthage, no NPM-style dependency hell
- Reproducible builds
- Fast incremental compilation

## Package Dependencies

### External Dependencies (Curated)

Substation has exactly **one** external dependency:

#### swift-crypto (Apple-maintained)

```swift
.package(url: "https://github.com/apple/swift-crypto.git", from: "3.0.0")
```

**Purpose**: AES-256-GCM encryption for credentials

**Why?**

- Apple-maintained and audited
- Cross-platform (macOS + Linux)
- Provides authenticated encryption (no padding oracle attacks)
- Essential for secure credential storage

**Replaced**: Weak XOR encryption on Linux (security audit fix, October 2025)

### System Dependencies

#### Foundation (Swift Standard Library)

**Included with Swift** - No separate installation needed

**Usage**:

- Data types (String, Array, Dictionary)
- Date and time handling
- File I/O
- URL handling
- JSON encoding/decoding

#### NCurses (Terminal Rendering)

**Platform-specific installation:**

**macOS:**

- Pre-installed with macOS
- No action needed

**Linux (Ubuntu/Debian):**

```bash
sudo apt install -y libncurses6 libncurses-dev
```

**Linux (RHEL/CentOS/Fedora):**

```bash
sudo dnf install -y ncurses-libs ncurses-devel
```

**Usage**:

- Terminal control (cursor movement, colors, attributes)
- Input handling (keyboard, mouse)
- Screen management (resize, refresh)

## Platform Support

### macOS: Native Support with Darwin APIs

**Supported Versions**: macOS 13+ (Ventura and later)

**Platform-Specific Features:**

- **Keychain Integration** - Secure credential storage (not used in current implementation)
- **autoreleasepool** - Memory management optimization
- **Native NCurses** - Pre-installed with system

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

**Supported Distributions:**

- Ubuntu 20.04+
- Debian 11+
- RHEL 8+
- CentOS 8+
- Fedora 35+

**Platform-Specific Features:**

- **File-based Credential Storage** - No keychain equivalent
- **Manual Memory Management** - No autoreleasepool
- **NCurses Dev Headers** - Require explicit installation

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

**Purpose**: Unified timer implementation across macOS and Linux

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

**Benefits:**

- Same interface across platforms
- No conditional compilation in application code
- Testable in isolation

### Windows Support: Not Yet

**Status**: Not supported

**Why?**

- Windows terminal APIs are fundamentally different (not NCurses-based)
- Swift on Windows has limited server-side support
- Cross-platform terminal abstraction is complex

**Workaround for Windows Users:**

Use WSL2 (Windows Subsystem for Linux):

```bash
# Install WSL2 and Ubuntu
wsl --install

# Inside WSL2
git clone https://github.com/cloudnull/substation.git
cd substation
~/.swiftly/bin/swift build -c release
```

**Future**: If you're a Windows expert who wants to help, PRs welcome.

## Development Tools

### Build System: Swift Package Manager

**Features:**

- Zero-warning builds enforced
- Strict concurrency checking (Swift 6 mode)
- Cross-platform build support (macOS and Linux)

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

**Build Time** (on modern hardware):

- macOS (M-series): ~30 seconds clean build
- Linux (recent CPU): ~45 seconds clean build
- Incremental builds: 1-5 seconds

### Testing: XCTest with Comprehensive Test Suites

**Test Structure:**

```
/Tests/
  OSClientTests/        # OpenStack client tests
  SubstationTests/      # Application tests
  TUITests/             # UI framework tests
```

**Test Types:**

- **Unit Tests** - Individual component testing
- **Integration Tests** - Service interaction testing
- **Performance Tests** - Benchmarking and profiling

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

**User Documentation** (Markdown):

- Located in `/docs/`
- Built with MkDocs (or similar)
- Includes architecture diagrams (Mermaid)

### CI/CD: Cross-Platform Build Verification

**Automated Checks:**

1. **Build Verification** - Builds on macOS and Linux
2. **Test Execution** - Runs all tests
3. **Zero-Warning Check** - Verifies no warnings
4. **Code Coverage** - Tracks test coverage
5. **Security Scanning** - Checks for vulnerabilities

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

### Code Quality: Zero-Warning Build Standard

**Seriously. Zero. Warnings.**

Not "mostly zero". Not "zero except that one". **ZERO**.

**Enforcement:**

- Warnings become errors in CI
- Pre-commit hooks check for warnings
- Code review rejects PRs with warnings

**Why?**

Warnings become bugs in production. Examples:

- Concurrency warnings → race conditions
- Memory warnings → leaks or crashes
- Type warnings → runtime errors

**Build Script:**

```bash
#!/bin/bash
set -e  # Exit on error

# Build with strict warnings
swift build -c release -Xswiftc -warnings-as-errors

# Check warning count
WARNINGS=$(swift build -c release 2>&1 | grep -c "warning:" || true)
if [ "$WARNINGS" -ne 0 ]; then
    echo "ERROR: Build has $WARNINGS warnings"
    exit 1
fi

echo "SUCCESS: Zero warnings"
```

### Performance: Built-in Telemetry and Monitoring

**Real-Time Metrics** (`/Sources/Substation/Telemetry/`):

- Cache hit rates (L1/L2/L3)
- API response times (p50, p95, p99)
- Memory usage (RSS, cache size)
- Search performance (query time, result count)

**Automatic Benchmarking:**

- Runs every 5 minutes in background
- Tracks performance over time
- Alerts on 10%+ degradation

**Performance Dashboard:**

Press `h` in Substation to view:

- Cache hit rate: 80%+ target
- API response time: < 2s p95
- Memory usage: < 400MB typical
- Search latency: < 500ms average

## Version Management

### Swiftly (Recommended)

**What is Swiftly?**

Official Swift version manager from the Swift Server Working Group.

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

**Benefits:**

- Manage multiple Swift versions
- Easy switching between versions
- Consistent across macOS and Linux
- Official support from Swift project

## Related Documentation

For more details on the architecture:

- **[Architecture Overview](./overview.md)** - High-level design principles
- **[Components](./components.md)** - Detailed component architecture
- **[Performance](../performance/index.md)** - Performance benchmarking
- **[Security](../concepts/security.md)** - Security implementation

---

**Note**: This technology stack documentation is based on the current implementation. All technologies mentioned are actively used in production.
