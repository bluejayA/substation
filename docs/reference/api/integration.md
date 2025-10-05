# Integration Guide

CrossPlatformTimer utilities and integration examples for building complete applications with OSClient and SwiftTUI.

## CrossPlatformTimer API

### Timer Creation

```swift
import CrossPlatformTimer

// Create a timer
let timer = createCompatibleTimer(
    interval: 1.0,
    repeats: true
) {
    print("Timer fired!")
}

// One-shot timer
let oneShot = createCompatibleTimer(
    interval: 5.0,
    repeats: false
) {
    print("One-time action")
}
```

### Timer Management

```swift
// Platform-specific timer handling
#if canImport(Darwin)
// macOS/iOS timer implementation
let timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: repeats, block: action)
#else
// Linux timer implementation
let timer = DispatchSource.makeTimerSource(queue: .main)
timer.schedule(deadline: .now() + interval, repeating: repeats ? interval : .never)
timer.setEventHandler(handler: action)
timer.resume()
#endif
```

### High-Performance Timing

```swift
// For animation timing (60+ FPS)
let animationTimer = createCompatibleTimer(interval: 1.0/60.0, repeats: true) {
    // Update animation frame
    updateFrame()
}

// For periodic background tasks
let backgroundTimer = createCompatibleTimer(interval: 30.0, repeats: true) {
    // Perform background maintenance
    performMaintenance()
}
```

## Complete Application Example

### Full OpenStack TUI Application

```swift
import OSClient
import SwiftTUI
import CrossPlatformTimer

@main
struct MyOpenStackApp {
    static func main() async {
        let screen = SwiftTUI.initializeScreen()
        defer { SwiftTUI.cleanup(screen) }

        // Initialize OpenStack client
        let client = try await OpenStackClient.connect(
            config: OpenStackConfig(authUrl: "https://keystone.example.com:5000/v3"),
            credentials: OpenStackCredentials(
                username: "admin",
                password: "secret",
                projectName: "admin"
            )
        )

        // Create UI surface
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: 0, y: 0, width: 80, height: 24)

        // Set up refresh timer
        let refreshTimer = createCompatibleTimer(interval: 5.0, repeats: true) {
            Task {
                await updateServerList(client: client, surface: surface, bounds: bounds)
            }
        }

        // Main application loop
        var running = true
        while running {
            let key = SwiftTUI.getInput(screen)
            if key == 113 { // 'q' key
                running = false
            }
        }
    }
}

func updateServerList(client: OpenStackClient, surface: Surface, bounds: Rect) async {
    do {
        let servers = try await client.nova.servers.list()
        let serverNames = servers.map { $0.name }

        let listComponent = List(items: serverNames)
        await SwiftTUI.render(listComponent, on: surface, in: bounds)
        SwiftTUI.refresh(surface.screen)
    } catch {
        let errorText = Text("Error: \(error.localizedDescription)").color(.red)
        await SwiftTUI.render(errorText, on: surface, in: bounds)
    }
}
```

## Common Integration Patterns

### Pattern 1: Server List with Auto-Refresh

```swift
actor ServerListView {
    private let client: OpenStackClient
    private var servers: [Server] = []
    private var selectedIndex: Int = 0
    private var refreshTimer: Timer?

    init(client: OpenStackClient) {
        self.client = client
    }

    func startAutoRefresh() {
        refreshTimer = createCompatibleTimer(interval: 5.0, repeats: true) {
            Task {
                await self.refresh()
            }
        }
    }

    func refresh() async {
        do {
            servers = try await client.nova.servers.list()
        } catch {
            print("Error refreshing servers: \(error)")
        }
    }

    func render(on surface: Surface, in bounds: Rect) async {
        let serverNames = servers.map { $0.name }
        let list = List(items: serverNames)
            .selectedIndex(selectedIndex)
            .scrollable(true)

        await SwiftTUI.render(list, on: surface, in: bounds)
    }

    func moveUp() {
        selectedIndex = max(0, selectedIndex - 1)
    }

    func moveDown() {
        selectedIndex = min(servers.count - 1, selectedIndex + 1)
    }

    func selectedServer() -> Server? {
        guard selectedIndex < servers.count else { return nil }
        return servers[selectedIndex]
    }
}
```

### Pattern 2: Multi-View Application

```swift
enum AppView {
    case dashboard
    case servers
    case networks
    case volumes
}

actor Application {
    private let client: OpenStackClient
    private let screen: Screen
    private var currentView: AppView = .dashboard
    private var running = true

    init(client: OpenStackClient, screen: Screen) {
        self.client = client
        self.screen = screen
    }

    func run() async {
        while running {
            await render()
            await handleInput()
        }
    }

    private func render() async {
        let surface = SwiftTUI.surface(from: screen)
        let bounds = Rect(x: 0, y: 0, width: 80, height: 24)

        switch currentView {
        case .dashboard:
            await renderDashboard(on: surface, in: bounds)
        case .servers:
            await renderServers(on: surface, in: bounds)
        case .networks:
            await renderNetworks(on: surface, in: bounds)
        case .volumes:
            await renderVolumes(on: surface, in: bounds)
        }

        SwiftTUI.refresh(screen)
    }

    private func handleInput() async {
        let key = SwiftTUI.getInput(screen)

        switch key {
        case Int32(UnicodeScalar("d").value):
            currentView = .dashboard
        case Int32(UnicodeScalar("s").value):
            currentView = .servers
        case Int32(UnicodeScalar("n").value):
            currentView = .networks
        case Int32(UnicodeScalar("v").value):
            currentView = .volumes
        case Int32(UnicodeScalar("q").value):
            running = false
        default:
            break
        }
    }

    private func renderDashboard(on surface: Surface, in bounds: Rect) async {
        let text = Text("Dashboard View - Press 's' for servers, 'n' for networks, 'v' for volumes")
            .bold()
        await SwiftTUI.render(text, on: surface, in: bounds)
    }

    private func renderServers(on surface: Surface, in bounds: Rect) async {
        do {
            let servers = try await client.nova.servers.list()
            let columns = [
                TableColumn(header: "Name", width: 30) { $0.name },
                TableColumn(header: "Status", width: 15) { $0.status.rawValue },
                TableColumn(header: "Created", width: 20) { formatDate($0.created) }
            ]

            let table = Table(data: servers, columns: columns)
            await SwiftTUI.render(table, on: surface, in: bounds)
        } catch {
            let errorText = Text("Error loading servers: \(error)").color(.red)
            await SwiftTUI.render(errorText, on: surface, in: bounds)
        }
    }

    private func renderNetworks(on surface: Surface, in bounds: Rect) async {
        // Similar to renderServers
    }

    private func renderVolumes(on surface: Surface, in bounds: Rect) async {
        // Similar to renderServers
    }
}

func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
}
```

### Pattern 3: Form-Based Resource Creation

```swift
actor ServerCreateView {
    private let client: OpenStackClient
    private var name: String = ""
    private var flavorId: String = ""
    private var imageId: String = ""
    private var currentField: Int = 0

    init(client: OpenStackClient) {
        self.client = client
    }

    func render(on surface: Surface, in bounds: Rect) async {
        let form = Form {
            FormField.text(
                label: "Server Name",
                value: name,
                isSelected: currentField == 0,
                isRequired: true
            )
            FormField.selector(
                label: "Flavor",
                items: await loadFlavors(),
                selectedId: flavorId,
                isSelected: currentField == 1
            )
            FormField.selector(
                label: "Image",
                items: await loadImages(),
                selectedId: imageId,
                isSelected: currentField == 2
            )
        }

        await SwiftTUI.render(form, on: surface, in: bounds)
    }

    private func loadFlavors() async -> [Flavor] {
        do {
            return try await client.nova.flavors.list()
        } catch {
            return []
        }
    }

    private func loadImages() async -> [Image] {
        do {
            return try await client.glance.images.list()
        } catch {
            return []
        }
    }

    func nextField() {
        currentField = min(2, currentField + 1)
    }

    func previousField() {
        currentField = max(0, currentField - 1)
    }

    func submit() async throws {
        guard !name.isEmpty, !flavorId.isEmpty, !imageId.isEmpty else {
            throw ValidationError.incompleteForm
        }

        let server = try await client.nova.servers.create(
            name: name,
            flavorRef: flavorId,
            imageRef: imageId
        )

        print("Created server: \(server.id)")
    }
}

enum ValidationError: Error {
    case incompleteForm
}
```

### Pattern 4: Real-Time Status Monitoring

```swift
actor StatusMonitor {
    private let client: OpenStackClient
    private var healthMetrics: [String: Any] = [:]
    private var monitorTimer: Timer?

    init(client: OpenStackClient) {
        self.client = client
    }

    func startMonitoring() {
        monitorTimer = createCompatibleTimer(interval: 10.0, repeats: true) {
            Task {
                await self.updateMetrics()
            }
        }
    }

    func stopMonitoring() {
        monitorTimer?.invalidate()
        monitorTimer = nil
    }

    private func updateMetrics() async {
        do {
            // Get cache statistics
            let cacheStats = await client.cacheManager.statistics()
            healthMetrics["cacheHitRate"] = cacheStats.hitRate
            healthMetrics["cacheSize"] = cacheStats.currentSize

            // Get performance metrics
            let perfMonitor = await client.performanceMonitor
            let perfMetrics = await perfMonitor.metrics()
            healthMetrics["apiCallCount"] = perfMetrics.apiCallCount
            healthMetrics["averageLatency"] = perfMetrics.averageLatency

            // Count resources
            let serverCount = try await client.nova.servers.list().count
            healthMetrics["serverCount"] = serverCount
        } catch {
            print("Error updating metrics: \(error)")
        }
    }

    func render(on surface: Surface, in bounds: Rect) async {
        let metricsText = """
        Cache Hit Rate: \(String(format: "%.1f%%", (healthMetrics["cacheHitRate"] as? Double ?? 0) * 100))
        Cache Size: \(healthMetrics["cacheSize"] as? Int ?? 0) bytes
        API Calls: \(healthMetrics["apiCallCount"] as? Int ?? 0)
        Avg Latency: \(String(format: "%.2f", healthMetrics["averageLatency"] as? TimeInterval ?? 0))s
        Servers: \(healthMetrics["serverCount"] as? Int ?? 0)
        """

        let text = Text(metricsText).color(.green)
        await SwiftTUI.render(text, on: surface, in: bounds)
    }
}
```

## Using Individual Packages

### OSClient Only

```swift
import OSClient

let client = try await OpenStackClient.connect(
    config: OpenStackConfig(authUrl: "https://keystone.example.com:5000/v3"),
    credentials: OpenStackCredentials(
        username: "admin",
        password: "secret",
        projectName: "admin"
    )
)

let servers = try await client.nova.servers.list()
for server in servers {
    print("\(server.name): \(server.status)")
}
```

### SwiftTUI Only

```swift
import SwiftTUI

let screen = SwiftTUI.initializeScreen()
defer { SwiftTUI.cleanup(screen) }

let surface = SwiftTUI.surface(from: screen)
let bounds = Rect(x: 0, y: 0, width: 80, height: 24)

await SwiftTUI.render(
    Text("Hello, World!").bold().color(.blue),
    on: surface,
    in: bounds
)

SwiftTUI.refresh(screen)

// Wait for input
_ = SwiftTUI.getInput(screen)
```

### CrossPlatformTimer Only

```swift
import CrossPlatformTimer

let timer = createCompatibleTimer(interval: 1.0, repeats: true) {
    print("Tick: \(Date())")
}

// Keep running for 10 seconds
Thread.sleep(forTimeInterval: 10.0)

timer.invalidate()
```

## Best Practices

### 1. Separate Concerns with Actors

```swift
// Good: Each view is an actor
actor ServerListView { }
actor NetworkListView { }
actor DashboardView { }

// Coordinate with a main application actor
actor Application {
    private let serverView: ServerListView
    private let networkView: NetworkListView
    private let dashboardView: DashboardView
}
```

### 2. Handle Errors Gracefully

```swift
// Good: Show user-friendly error messages
do {
    let servers = try await client.nova.servers.list()
} catch OpenStackError.authentication(let message) {
    await showError("Authentication failed: \(message)")
} catch OpenStackError.timeout {
    await showError("Request timed out. Check your connection.")
} catch {
    await showError("An error occurred: \(error.localizedDescription)")
}
```

### 3. Use Timers for Background Updates

```swift
// Good: Periodic refresh with timer
let refreshTimer = createCompatibleTimer(interval: 5.0, repeats: true) {
    Task {
        await refreshData()
    }
}

// Don't: Busy loop
// while true {
//     await refreshData()
//     Thread.sleep(forTimeInterval: 5.0)  // Blocks thread
// }
```

### 4. Clean Up Resources

```swift
// Good: Use defer for cleanup
func runApp() async {
    let screen = SwiftTUI.initializeScreen()
    defer { SwiftTUI.cleanup(screen) }

    let timer = createCompatibleTimer(...)
    defer { timer.invalidate() }

    // App code here
}
```

### 5. Optimize Rendering

```swift
// Good: Only render when data changes
var lastRenderedServers: [Server] = []

func render() async {
    guard servers != lastRenderedServers else { return }

    await SwiftTUI.render(serverList, on: surface, in: bounds)
    SwiftTUI.refresh(screen)

    lastRenderedServers = servers
}

// Don't: Render on every loop iteration
// while running {
//     await SwiftTUI.render(...)  // Wasteful if nothing changed
// }
```

## Testing Integration

### Mock OpenStack Client

```swift
#if DEBUG
actor MockOpenStackClient: OpenStackClient {
    var mockServers: [Server] = []

    func nova.servers.list() async throws -> [Server] {
        return mockServers
    }
}
#endif
```

### Integration Tests

```swift
func testServerListIntegration() async throws {
    let mockClient = MockOpenStackClient()
    mockClient.mockServers = [
        Server(id: "1", name: "test-server", status: .active)
    ]

    let view = ServerListView(client: mockClient)
    await view.refresh()

    let servers = await view.servers
    XCTAssertEqual(servers.count, 1)
    XCTAssertEqual(servers[0].name, "test-server")
}
```

## Troubleshooting

### Common Integration Issues

**Issue**: Timer not firing

```swift
// Problem: Timer not retained
func startTimer() {
    let timer = createCompatibleTimer(...)  // Goes out of scope
}

// Solution: Keep reference
class MyApp {
    var timer: Timer?

    func startTimer() {
        timer = createCompatibleTimer(...)
    }
}
```

**Issue**: Screen not updating

```swift
// Problem: Forgot to call refresh
await SwiftTUI.render(component, on: surface, in: bounds)
// Missing: SwiftTUI.refresh(screen)

// Solution: Always refresh after rendering
await SwiftTUI.render(component, on: surface, in: bounds)
SwiftTUI.refresh(screen)  // Now screen updates
```

**Issue**: Actor isolation errors

```swift
// Problem: Accessing actor state from non-isolated context
let servers = view.servers  // Error: actor-isolated property

// Solution: Use await
let servers = await view.servers  // Correct
```

---

**See Also**:

- [OSClient API](osclient.md) - OpenStack client library reference
- [SwiftTUI API](swifttui.md) - Terminal UI framework reference
- [API Reference Index](index.md) - Quick reference and navigation
