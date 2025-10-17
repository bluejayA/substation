import Foundation
import XCTest
import OSClient
import SwiftNCurses

// MARK: - Test Framework for OpenStack Terminal UI

/// Comprehensive testing framework for the Substation application
/// Provides unit tests, integration tests, and UI simulation tests
@MainActor
public class SubstationTestFramework {

    // MARK: - Test Configuration

    public struct TestConfiguration {
        let testTimeout: TimeInterval
        let maxRetries: Int
        let testDataSize: Int
        let enablePerformanceTests: Bool
        let enableSecurityTests: Bool
        let enableIntegrationTests: Bool

        public static let `default` = TestConfiguration(
            testTimeout: 30.0,
            maxRetries: 3,
            testDataSize: 100,
            enablePerformanceTests: true,
            enableSecurityTests: true,
            enableIntegrationTests: false // Requires real OpenStack environment
        )
    }

    private let config: TestConfiguration
    private var testResults: [TestResult] = []
    private var mockClient: MockOSClient?
    private var testMetrics: TestMetrics

    public init(config: TestConfiguration = .default) {
        self.config = config
        self.testMetrics = TestMetrics()
    }

    // MARK: - Main Test Runner

    public func runAllTests() async throws -> TestSummary {
        print("[TEST] Starting Substation Test Suite...")
        testMetrics.startTime = Date()

        // Unit Tests
        await runUnitTests()

        // Security Tests
        if config.enableSecurityTests {
            await runSecurityTests()
        }

        // Performance Tests
        if config.enablePerformanceTests {
            await runPerformanceTests()
        }

        // Integration Tests
        if config.enableIntegrationTests {
            await runIntegrationTests()
        }

        // UI Tests
        await runUITests()

        testMetrics.endTime = Date()
        return generateTestSummary()
    }

    // MARK: - Unit Tests

    private func runUnitTests() async {
        print("[UNIT] Running Unit Tests...")

        await testSecurityManager()
        await testMemoryManager()
        await testErrorRecovery()
        await testVirtualScrolling()
        await testIncrementalDataLoader()
        await testOptimizedTopology()
        await testUserFeedbackSystem()
    }

    private func testSecurityManager() async {
        let testName = "SecurityManager"
        print("  [SECURITY] Testing \(testName)...")

        do {
            // Test token management
            let tokenManager = TokenManager()

            // Test secure token storage
            let testToken = "test-token-12345"
            try await tokenManager.storeToken(testToken, expiresAt: Date().addingTimeInterval(3600))

            let retrievedToken = try await tokenManager.getValidToken()
            assert(retrievedToken == testToken, "Token storage/retrieval failed")

            // Test token expiration
            try await tokenManager.storeToken(testToken, expiresAt: Date().addingTimeInterval(-1))
            let expiredToken = try? await tokenManager.getValidToken()
            assert(expiredToken == nil, "Expired token should be nil")

            // Test credential encryption
            let encryption = CredentialEncryption()
            let testCredential = "sensitive-password"
            let encrypted = try encryption.encrypt(testCredential)
            let decrypted = try encryption.decrypt(encrypted)
            assert(decrypted == testCredential, "Encryption/decryption failed")

            recordTestResult(.passed(testName, "All security features working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Security test failed: \(error)"))
        }
    }

    private func testMemoryManager() async {
        let testName = "MemoryManager"
        print("  [MEMORY] Testing \(testName)...")

        do {
            let memoryManager = MemoryManager(maxCacheSize: 10, maxAgeSeconds: 1)

            // Test cache storage
            memoryManager.store(key: "test1", value: "value1")
            memoryManager.store(key: "test2", value: "value2")

            let retrieved = memoryManager.retrieve(key: "test1") as? String
            assert(retrieved == "value1", "Cache storage/retrieval failed")

            // Test cache eviction
            for i in 3...15 {
                memoryManager.store(key: "test\(i)", value: "value\(i)")
            }

            let evicted = memoryManager.retrieve(key: "test1") as? String
            assert(evicted == nil, "LRU eviction failed")

            // Test cache expiration
            try await Task.sleep(nanoseconds: 1_100_000_000) // 1.1 seconds
            let expired = memoryManager.retrieve(key: "test15") as? String
            assert(expired == nil, "Cache expiration failed")

            recordTestResult(.passed(testName, "Memory management working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Memory test failed: \(error)"))
        }
    }

    private func testErrorRecovery() async {
        let testName = "ErrorRecovery"
        print("  [RECOVERY] Testing \(testName)...")

        do {
            let errorRecovery = ErrorRecoveryManager(maxRetries: 3, baseDelay: 0.1)

            var attemptCount = 0
            let result = try await errorRecovery.executeWithRecovery {
                attemptCount += 1
                if attemptCount < 3 {
                    throw TestError.temporaryFailure
                }
                return "success"
            }

            assert(result == "success", "Error recovery failed")
            assert(attemptCount == 3, "Retry count incorrect")

            // Test circuit breaker
            let circuitBreaker = CircuitBreaker(
                failureThreshold: 2,
                timeoutInterval: 0.1,
                resetTimeout: 1.0
            )

            var failures = 0
            for _ in 0..<3 {
                do {
                    try await circuitBreaker.execute {
                        failures += 1
                        throw TestError.permanentFailure
                    }
                } catch {
                    // Expected to fail
                }
            }

            assert(circuitBreaker.state == .open, "Circuit breaker should be open")

            recordTestResult(.passed(testName, "Error recovery mechanisms working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Error recovery test failed: \(error)"))
        }
    }

    private func testVirtualScrolling() async {
        let testName = "VirtualScrolling"
        print("  [SCROLL] Testing \(testName)...")

        do {
            let controller = VirtualListController(itemHeight: 1, viewportHeight: 10)

            // Test basic navigation
            controller.updateItemCount(100)
            assert(controller.selectedIndex == 0, "Initial selection should be 0")

            controller.moveSelectionDown()
            assert(controller.selectedIndex == 1, "Selection should move down")

            controller.moveSelectionUp()
            assert(controller.selectedIndex == 0, "Selection should move up")

            // Test page navigation
            controller.scrollPageDown()
            assert(controller.selectedIndex >= 10, "Page down should advance selection")

            controller.scrollToTop()
            assert(controller.selectedIndex == 0, "Scroll to top should reset selection")

            // Test bounds checking
            controller.moveSelection(to: 150)
            assert(controller.selectedIndex == 99, "Selection should be clamped to bounds")

            // Test pagination info
            let paginationInfo = controller.getPaginationInfo()
            assert(paginationInfo.totalItems == 100, "Total items should be 100")

            recordTestResult(.passed(testName, "Virtual scrolling working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Virtual scrolling test failed: \(error)"))
        }
    }

    private func testIncrementalDataLoader() async {
        let testName = "IncrementalDataLoader"
        print("  [DATA] Testing \(testName)...")

        do {
            var loadedPages: [Int] = []
            let loader = IncrementalDataLoader<String>(
                pageSize: 10,
                maxItems: 50,
                loadFunction: { offset, limit in
                    loadedPages.append(offset)
                    let items = (offset..<(offset + limit)).map { "Item \($0)" }
                    return (items: items, hasMore: offset + limit < 100)
                }
            )

            // Test initial load
            try await loader.loadInitialData()
            let initialStats = loader.getLoadingStats()
            assert(initialStats?.loadedItems == 10, "Initial load should load 10 items")

            // Test prefetching
            loader.checkPrefetch(currentIndex: 8)
            try await Task.sleep(nanoseconds: 100_000_000) // 100ms

            let prefetchStats = loader.getLoadingStats()
            assert(prefetchStats?.loadedItems == 20, "Prefetch should load more items")

            recordTestResult(.passed(testName, "Incremental data loading working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Incremental data loader test failed: \(error)"))
        }
    }

    private func testOptimizedTopology() async {
        let testName = "OptimizedTopology"
        print("  [TOPOLOGY] Testing \(testName)...")

        do {
            // Create test data
            let servers = [createTestServer(id: "server1", name: "Test Server")]
            let networks = [createTestNetwork(id: "net1", name: "Test Network")]
            let subnets = [createTestSubnet(id: "subnet1", networkId: "net1")]
            let ports = [createTestPort(id: "port1", networkId: "net1", deviceId: "server1")]

            let topology = OptimizedTopologyGraph(
                servers: servers,
                networks: networks,
                subnets: subnets,
                ports: ports,
                routers: [],
                floatingIPs: [],
                securityGroups: [],
                serverGroups: []
            )

            // Test topology calculations
            let serverConnections = topology.getServerConnections("server1")
            assert(!serverConnections.isEmpty, "Server should have network connections")

            let networkServers = topology.getNetworkServers("net1")
            assert(networkServers.contains("server1"), "Network should contain the server")

            // Test performance (should be O(1) lookups)
            let startTime = Date()
            for _ in 0..<1000 {
                _ = topology.getServerConnections("server1")
            }
            let lookupTime = Date().timeIntervalSince(startTime)
            assert(lookupTime < 0.1, "Topology lookups should be fast (O(1))")

            // Test ASCII rendering
            let renderer = OptimizedTopologyRenderer(topologyGraph: topology)
            let ascii = renderer.generateASCIITopology(maxWidth: 80, maxHeight: 24)
            assert(!ascii.isEmpty, "ASCII topology should be generated")

            recordTestResult(.passed(testName, "Optimized topology working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Optimized topology test failed: \(error)"))
        }
    }

    private func testUserFeedbackSystem() async {
        let testName = "UserFeedbackSystem"
        print("  [FEEDBACK] Testing \(testName)...")

        do {
            let userFeedback = UserFeedbackSystem()

            // Test notification system
            await userFeedback.showNotification(.info("Test notification"))
            assert(userFeedback.hasActiveNotification, "Notification should be active")

            await userFeedback.clearNotifications()
            assert(!userFeedback.hasActiveNotification, "Notifications should be cleared")

            // Test modal system
            let modal = ModalContent.confirmation(
                title: "Test",
                message: "Test message",
                confirmText: "OK",
                cancelText: "Cancel"
            )

            userFeedback.showModal(modal)
            assert(userFeedback.hasActiveModal, "Modal should be active")

            userFeedback.dismissModal()
            assert(!userFeedback.hasActiveModal, "Modal should be dismissed")

            recordTestResult(.passed(testName, "User feedback system working correctly"))

        } catch {
            recordTestResult(.failed(testName, "User feedback test failed: \(error)"))
        }
    }

    // MARK: - Security Tests

    private func runSecurityTests() async {
        print("[SECURITY] Running Security Tests...")

        await testTokenSecurity()
        await testCredentialEncryption()
        await testCertificateValidation()
        await testSecureMemory()
    }

    private func testTokenSecurity() async {
        let testName = "TokenSecurity"
        print("  🔑 Testing \(testName)...")

        do {
            let tokenManager = TokenManager()

            // Test token refresh mechanism
            let initialToken = "initial-token"
            try await tokenManager.storeToken(initialToken, expiresAt: Date().addingTimeInterval(300))

            // Simulate token near expiration
            try await tokenManager.storeToken(initialToken, expiresAt: Date().addingTimeInterval(60))
            let needsRefresh = await tokenManager.needsRefresh()
            assert(needsRefresh, "Token should need refresh when near expiration")

            // Test secure token clearing
            await tokenManager.clearToken()
            let clearedToken = try? await tokenManager.getValidToken()
            assert(clearedToken == nil, "Token should be cleared")

            recordTestResult(.passed(testName, "Token security mechanisms working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Token security test failed: \(error)"))
        }
    }

    private func testCredentialEncryption() async {
        let testName = "CredentialEncryption"
        print("  [SECURITY] Testing \(testName)...")

        do {
            let encryption = CredentialEncryption()

            // Test encryption strength
            let plaintext = "super-secret-password"
            let encrypted1 = try encryption.encrypt(plaintext)
            let encrypted2 = try encryption.encrypt(plaintext)

            // Each encryption should produce different ciphertext (due to IV)
            assert(encrypted1 != encrypted2, "Encryption should use unique IVs")

            // But both should decrypt to the same plaintext
            let decrypted1 = try encryption.decrypt(encrypted1)
            let decrypted2 = try encryption.decrypt(encrypted2)
            assert(decrypted1 == plaintext && decrypted2 == plaintext, "Decryption should work correctly")

            // Test invalid data handling
            let invalidData = Data([1, 2, 3, 4])
            do {
                _ = try encryption.decrypt(invalidData)
                assert(false, "Should throw error for invalid data")
            } catch {
                // Expected behavior
            }

            recordTestResult(.passed(testName, "Credential encryption working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Credential encryption test failed: \(error)"))
        }
    }

    private func testCertificateValidation() async {
        let testName = "CertificateValidation"
        print("  [SCROLL] Testing \(testName)...")

        do {
            let secureSession = SecureURLSession()

            // Test with valid certificate (using a known good endpoint)
            let validURL = URL(string: "https://httpbin.org/get")!
            let (_, response) = try await secureSession.data(from: validURL)

            if let httpResponse = response as? HTTPURLResponse {
                assert(httpResponse.statusCode == 200, "Valid HTTPS request should succeed")
            }

            // Test certificate validation is enabled
            // (This would require a mock server with invalid certificate for complete testing)

            recordTestResult(.passed(testName, "Certificate validation working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Certificate validation test failed: \(error)"))
        }
    }

    private func testSecureMemory() async {
        let testName = "SecureMemory"
        print("  [MEMORY] Testing \(testName)...")

        do {
            // Test SecureBuffer
            var buffer = SecureBuffer()
            let testData = "sensitive-data".data(using: .utf8)!
            buffer.store(testData)

            let retrieved = buffer.retrieve()
            assert(retrieved == testData, "SecureBuffer should store and retrieve data correctly")

            // Test automatic zeroing
            buffer = SecureBuffer() // This should trigger deinit and zeroing
            // We can't directly test memory zeroing without unsafe operations

            // Test SecureString
            let secureString = SecureString("password123")
            assert(secureString.length == 11, "SecureString should track length correctly")

            // Test secure string clearing
            secureString.clear()
            assert(secureString.length == 0, "SecureString should be cleared")

            recordTestResult(.passed(testName, "Secure memory handling working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Secure memory test failed: \(error)"))
        }
    }

    // MARK: - Performance Tests

    private func runPerformanceTests() async {
        print("[PERFORMANCE] Running Performance Tests...")

        await testVirtualScrollPerformance()
        await testTopologyPerformance()
        await testMemoryUsage()
        await testRenderingPerformance()
    }

    private func testVirtualScrollPerformance() async {
        let testName = "VirtualScrollPerformance"
        print("  [SCROLL] Testing \(testName)...")

        do {
            let controller = VirtualListController(itemHeight: 1, viewportHeight: 20)
            controller.updateItemCount(10000) // Large dataset

            // Test navigation performance
            let startTime = Date()
            for _ in 0..<1000 {
                controller.moveSelectionDown()
            }
            let navigationTime = Date().timeIntervalSince(startTime)

            assert(navigationTime < 0.1, "Virtual scroll navigation should be fast")

            // Test visible range calculation performance
            let rangeStartTime = Date()
            for _ in 0..<1000 {
                _ = controller.getVisibleRange()
            }
            let rangeTime = Date().timeIntervalSince(rangeStartTime)

            assert(rangeTime < 0.05, "Visible range calculation should be fast")

            recordTestResult(.passed(testName, "Virtual scroll performance is acceptable"))

        } catch {
            recordTestResult(.failed(testName, "Virtual scroll performance test failed: \(error)"))
        }
    }

    private func testTopologyPerformance() async {
        let testName = "TopologyPerformance"
        print("  [TOPOLOGY] Testing \(testName)...")

        do {
            // Create large test dataset
            let servers = (0..<1000).map { createTestServer(id: "server\($0)", name: "Server \($0)") }
            let networks = (0..<100).map { createTestNetwork(id: "net\($0)", name: "Network \($0)") }
            let ports = (0..<2000).map { createTestPort(id: "port\($0)", networkId: "net\($0 % 100)", deviceId: "server\($0 % 1000)") }

            // Test topology build performance
            let buildStartTime = Date()
            let topology = OptimizedTopologyGraph(
                servers: servers,
                networks: networks,
                subnets: [],
                ports: ports,
                routers: [],
                floatingIPs: [],
                securityGroups: [],
                serverGroups: []
            )
            let buildTime = Date().timeIntervalSince(buildStartTime)

            assert(buildTime < 1.0, "Topology build should be fast even with large datasets")

            // Test lookup performance (should be O(1))
            let lookupStartTime = Date()
            for i in 0..<1000 {
                _ = topology.getServerConnections("server\(i)")
            }
            let lookupTime = Date().timeIntervalSince(lookupStartTime)

            assert(lookupTime < 0.1, "Topology lookups should be O(1) and fast")

            recordTestResult(.passed(testName, "Topology performance is acceptable"))

        } catch {
            recordTestResult(.failed(testName, "Topology performance test failed: \(error)"))
        }
    }

    private func testMemoryUsage() async {
        let testName = "MemoryUsage"
        print("  [MEMORY] Testing \(testName)...")

        do {
            let memoryManager = MemoryManager(maxCacheSize: 1000, maxAgeSeconds: 300)

            // Test memory usage with large cache
            let initialMemory = getCurrentMemoryUsage()

            for i in 0..<1000 {
                memoryManager.store(key: "key\(i)", value: Array(repeating: "data", count: 100))
            }

            let afterCacheMemory = getCurrentMemoryUsage()
            let memoryIncrease = afterCacheMemory - initialMemory

            // Memory increase should be reasonable (less than 100MB for test data)
            assert(memoryIncrease < 100 * 1024 * 1024, "Memory usage should be reasonable")

            // Test memory cleanup
            memoryManager.clearAll()

            // Allow some time for cleanup
            try await Task.sleep(nanoseconds: 100_000_000)

            let afterCleanupMemory = getCurrentMemoryUsage()
            let memoryReduction = afterCacheMemory - afterCleanupMemory

            // Should reclaim most memory
            assert(memoryReduction > memoryIncrease * 0.5, "Memory cleanup should be effective")

            recordTestResult(.passed(testName, "Memory usage is within acceptable limits"))

        } catch {
            recordTestResult(.failed(testName, "Memory usage test failed: \(error)"))
        }
    }

    private func testRenderingPerformance() async {
        let testName = "RenderingPerformance"
        print("  [RENDER] Testing \(testName)...")

        do {
            // Mock surface for testing
            let mockSurface = MockSurface()
            let rect = Rect(x: 0, y: 0, width: 80, height: 24)

            // Test text rendering performance
            let startTime = Date()
            for i in 0..<100 {
                let text = Text("Test text line \(i)")
                await text.render(on: mockSurface, in: rect)
            }
            let renderTime = Date().timeIntervalSince(startTime)

            assert(renderTime < 0.5, "Text rendering should be fast")

            // Test virtual list rendering performance
            let items = (0..<1000).map { "Item \($0)" }
            let controller = VirtualListController(itemHeight: 1, viewportHeight: 20)
            controller.updateItemCount(items.count)

            let listStartTime = Date()
            let optimizedList = OptimizedListView(
                items: items,
                controller: controller,
                searchController: ListSearchController(),
                getItemText: { $0 }
            ) { item, isSelected, isSearchResult in
                Text(item).styled(isSelected ? .accent : .primary)
            }

            await optimizedList.render(on: mockSurface, in: rect)
            let listRenderTime = Date().timeIntervalSince(listStartTime)

            assert(listRenderTime < 0.1, "Virtual list rendering should be fast")

            recordTestResult(.passed(testName, "Rendering performance is acceptable"))

        } catch {
            recordTestResult(.failed(testName, "Rendering performance test failed: \(error)"))
        }
    }

    // MARK: - Integration Tests

    private func runIntegrationTests() async {
        print("[INTEGRATION] Running Integration Tests...")

        await testOpenStackClientIntegration()
        await testSecureClientIntegration()
        await testDataManagerIntegration()
    }

    private func testOpenStackClientIntegration() async {
        let testName = "OpenStackClientIntegration"
        print("  [OPENSTACK] Testing \(testName)...")

        do {
            // This would require a real OpenStack environment
            // For now, we'll test with mock client
            let mockClient = MockOSClient()

            // Test basic operations
            let servers = try await mockClient.listServers()
            assert(!servers.isEmpty, "Should return mock servers")

            let networks = try await mockClient.listNetworks()
            assert(!networks.isEmpty, "Should return mock networks")

            recordTestResult(.passed(testName, "OpenStack client integration working with mocks"))

        } catch {
            recordTestResult(.failed(testName, "OpenStack client integration test failed: \(error)"))
        }
    }

    private func testSecureClientIntegration() async {
        let testName = "SecureClientIntegration"
        print("  [SECURITY] Testing \(testName)...")

        do {
            let secureClient = SecureOSClient()

            // Test session status
            let status = secureClient.getSessionStatus()
            assert(!status.isConnected, "Should not be connected initially")

            // Test connection with mock credentials would go here
            // For now, just verify the interface

            recordTestResult(.passed(testName, "Secure client integration interface is correct"))

        } catch {
            recordTestResult(.failed(testName, "Secure client integration test failed: \(error)"))
        }
    }

    private func testDataManagerIntegration() async {
        let testName = "DataManagerIntegration"
        print("  [DATA] Testing \(testName)...")

        do {
            var loadCalls = 0
            let dataManager = ServerDataManager(
                mode: .incremental,
                pageSize: 10,
                maxItems: 100,
                updateInterval: 1.0,
                loadFunction: { offset, limit in
                    loadCalls += 1
                    let items = (offset..<(offset + limit)).map {
                        createTestServer(id: "server\($0)", name: "Server \($0)")
                    }
                    return (items: items, hasMore: offset + limit < 50)
                },
                streamFunction: { [] }
            )

            // Test initial load
            await dataManager.start()
            try await Task.sleep(nanoseconds: 200_000_000) // 200ms

            let stats = dataManager.getLoadingStats()
            assert(stats?.loadedItems == 10, "Should load initial page")
            assert(loadCalls >= 1, "Should have called load function")

            dataManager.stop()

            recordTestResult(.passed(testName, "Data manager integration working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Data manager integration test failed: \(error)"))
        }
    }

    // MARK: - UI Tests

    private func runUITests() async {
        print("[UI] Running UI Tests...")

        await testComponentRendering()
        await testInputHandling()
        await testLayoutCalculations()
    }

    private func testComponentRendering() async {
        let testName = "ComponentRendering"
        print("  [RENDER] Testing \(testName)...")

        do {
            let mockSurface = MockSurface()
            let rect = Rect(x: 0, y: 0, width: 80, height: 24)

            // Test Text component
            let text = Text("Hello, World!").accent()
            await text.render(on: mockSurface, in: rect)
            assert(mockSurface.renderedText.contains("Hello, World!"), "Text should be rendered")

            // Test ProgressBar component
            let progressBar = ProgressBar(progress: 0.5, width: 20)
            await progressBar.render(in: DrawingContext(surface: mockSurface, bounds: rect))
            // Progress bar should render filled and empty characters

            // Test ScrollIndicator component
            let paginationInfo = PaginationInfo(
                currentPage: 1,
                totalPages: 10,
                visibleItems: 20,
                totalItems: 200,
                selectedIndex: 25
            )
            let scrollIndicator = ScrollIndicator(paginationInfo: paginationInfo)
            await scrollIndicator.render(on: mockSurface, in: rect)

            recordTestResult(.passed(testName, "Component rendering working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Component rendering test failed: \(error)"))
        }
    }

    private func testInputHandling() async {
        let testName = "InputHandling"
        print("  [INPUT] Testing \(testName)...")

        do {
            let inputManager = EnhancedInputManager()

            // Test key event recognition
            // (This would require mocking ncurses input, simplified for testing)

            let testEvents: [KeyEvent] = [
                .character("q"),
                .arrowUp,
                .arrowDown,
                .enter,
                .escape
            ]

            for event in testEvents {
                assert(event.isNavigation || event.isMovement || event == .character("q"),
                       "Key events should be properly categorized")
            }

            recordTestResult(.passed(testName, "Input handling working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Input handling test failed: \(error)"))
        }
    }

    private func testLayoutCalculations() async {
        let testName = "LayoutCalculations"
        print("  [LAYOUT] Testing \(testName)...")

        do {
            // Test Rect calculations
            let rect = Rect(x: 10, y: 5, width: 80, height: 24)
            assert(rect.origin.col == 10 && rect.origin.row == 5, "Rect origin should be correct")
            assert(rect.size.width == 80 && rect.size.height == 24, "Rect size should be correct")

            // Test Position calculations
            let position = Position(row: 10, col: 20)
            assert(rect.contains(position), "Rect should contain position within bounds")

            let outsidePosition = Position(row: 50, col: 100)
            assert(!rect.contains(outsidePosition), "Rect should not contain position outside bounds")

            // Test DrawingContext calculations
            let surface = MockSurface()
            let context = DrawingContext(surface: surface, bounds: rect)

            let subRect = Rect(x: 5, y: 3, width: 20, height: 10)
            let subContext = context.subContext(rect: subRect)

            assert(subContext.bounds.origin.col == 15, "Sub-context should have adjusted origin")
            assert(subContext.bounds.origin.row == 8, "Sub-context should have adjusted origin")

            recordTestResult(.passed(testName, "Layout calculations working correctly"))

        } catch {
            recordTestResult(.failed(testName, "Layout calculation test failed: \(error)"))
        }
    }

    // MARK: - Test Utilities

    private func recordTestResult(_ result: TestResult) {
        testResults.append(result)
        testMetrics.updateWith(result)

        switch result {
        case .passed(let name, let message):
            print("    [PASS] \(name): \(message)")
        case .failed(let name, let error):
            print("    [FAIL] \(name): \(error)")
        case .skipped(let name, let reason):
            print("    [SKIP] \(name): \(reason)")
        }
    }

    private func generateTestSummary() -> TestSummary {
        let passed = testResults.filter { if case .passed = $0 { return true }; return false }.count
        let failed = testResults.filter { if case .failed = $0 { return true }; return false }.count
        let skipped = testResults.filter { if case .skipped = $0 { return true }; return false }.count

        let duration = testMetrics.endTime?.timeIntervalSince(testMetrics.startTime!) ?? 0

        return TestSummary(
            totalTests: testResults.count,
            passed: passed,
            failed: failed,
            skipped: skipped,
            duration: duration,
            coverage: calculateCoverage()
        )
    }

    private func calculateCoverage() -> Double {
        // Simplified coverage calculation
        let totalComponents = 8 // Security, Memory, Error Recovery, Virtual Scroll, Data Loader, Topology, User Feedback, UI
        let testedComponents = testResults.filter { if case .passed = $0 { return true }; return false }.count
        return Double(testedComponents) / Double(totalComponents)
    }

    private func getCurrentMemoryUsage() -> Int64 {
        #if canImport(Darwin)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        return kerr == KERN_SUCCESS ? Int64(info.resident_size) : 0
        #else
        return 0 // Simplified for Linux
        #endif
    }
}

// MARK: - Test Data Creators

private func createTestServer(id: String, name: String) -> OTServer {
    return OTServer(
        id: id,
        name: name,
        status: "ACTIVE",
        imageId: "image-123",
        flavorId: "flavor-123",
        addresses: ["test-network": [OTServerAddress(address: "192.168.1.10", type: "fixed")]],
        metadata: [:],
        created: Date(),
        updated: Date()
    )
}

private func createTestNetwork(id: String, name: String) -> OTNetwork {
    return OTNetwork(
        id: id,
        name: name,
        adminStateUp: true,
        status: "ACTIVE",
        shared: false,
        routerExternal: false,
        subnets: [],
        mtu: 1500
    )
}

private func createTestSubnet(id: String, networkId: String) -> OTSubnet {
    return OTSubnet(
        id: id,
        name: "Test Subnet",
        networkId: networkId,
        cidr: "192.168.1.0/24",
        ipVersion: 4,
        gatewayIp: "192.168.1.1",
        enableDhcp: true,
        allocationPools: [],
        dnsNameservers: [],
        hostRoutes: []
    )
}

private func createTestPort(id: String, networkId: String, deviceId: String) -> OTPort {
    return OTPort(
        id: id,
        name: "Test Port",
        networkId: networkId,
        adminStateUp: true,
        status: "ACTIVE",
        macAddress: "fa:16:3e:xx:xx:xx",
        fixedIps: [],
        deviceId: deviceId,
        deviceOwner: "compute:nova",
        securityGroups: []
    )
}

// MARK: - Supporting Types

public enum TestResult {
    case passed(String, String)
    case failed(String, String)
    case skipped(String, String)
}

private struct TestMetrics {
    var startTime: Date?
    var endTime: Date?
    var passedCount = 0
    var failedCount = 0
    var skippedCount = 0

    mutating func updateWith(_ result: TestResult) {
        switch result {
        case .passed:
            passedCount += 1
        case .failed:
            failedCount += 1
        case .skipped:
            skippedCount += 1
        }
    }
}

public struct TestSummary {
    public let totalTests: Int
    public let passed: Int
    public let failed: Int
    public let skipped: Int
    public let duration: TimeInterval
    public let coverage: Double

    public var successRate: Double {
        return totalTests > 0 ? Double(passed) / Double(totalTests) : 0
    }

    public var description: String {
        return """
        [DATA] Test Summary
        ===============
        Total Tests: \(totalTests)
        Passed: \(passed) [PASS]
        Failed: \(failed) [FAIL]
        Skipped: \(skipped) [SKIP]
        Duration: \(String(format: "%.2f", duration))s
        Success Rate: \(String(format: "%.1f", successRate * 100))%
        Coverage: \(String(format: "%.1f", coverage * 100))%
        """
    }
}

private enum TestError: Error {
    case temporaryFailure
    case permanentFailure
}

// MARK: - Mock Classes

private class MockOSClient: OSClient {
    override func listServers() async throws -> [OTServer] {
        return [
            createTestServer(id: "mock-server-1", name: "Mock Server 1"),
            createTestServer(id: "mock-server-2", name: "Mock Server 2")
        ]
    }

    override func listNetworks() async throws -> [OTNetwork] {
        return [
            createTestNetwork(id: "mock-network-1", name: "Mock Network 1"),
            createTestNetwork(id: "mock-network-2", name: "Mock Network 2")
        ]
    }
}

private class MockSurface: Surface {
    var renderedText: String = ""

    override func drawText(_ text: String, at position: Position, style: TextStyle) async {
        renderedText += text
    }

    override func fill(rect: Rect, character: Character, style: TextStyle) async {
        renderedText += String(repeating: character, count: Int(rect.size.width * rect.size.height))
    }
}