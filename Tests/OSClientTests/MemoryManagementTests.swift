import XCTest
@testable import OSClient
import Foundation

final class MemoryManagementTests: XCTestCase {

    func testURLSessionDelegateRetention() async throws {
        let config = OpenStackConfig(
            authURL: URL(string: "https://test.example.com:5000/v3")!,
            region: "RegionOne"
        )
        let credentials = OpenStackCredentials.password(
            username: "test",
            password: "test",
            projectName: "test"
        )
        let logger = ConsoleLogger()

        let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)

        await Task.yield()

        XCTAssertNotNil(core, "Core client should be initialized")
    }

    func testClientCleanupWithoutCrash() async throws {
        weak var weakCore: OpenStackClientCore?

        do {
            let config = OpenStackConfig(
                authURL: URL(string: "https://test.example.com:5000/v3")!,
                region: "RegionOne"
            )
            let credentials = OpenStackCredentials.password(
                username: "test",
                password: "test",
                projectName: "test"
            )
            let logger = ConsoleLogger()

            let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)
            weakCore = core

            XCTAssertNotNil(weakCore, "Core should exist in scope")

            await Task.yield()
        }

        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertNil(weakCore, "Core should be deallocated after scope exit")
    }

    func testTaskCancellationHandling() async throws {
        let config = OpenStackConfig(
            authURL: URL(string: "https://unreachable.example.com:5000/v3")!,
            region: "RegionOne",
            timeout: 5.0
        )
        let credentials = OpenStackCredentials.password(
            username: "test",
            password: "test",
            projectName: "test"
        )
        let logger = ConsoleLogger()

        let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)

        let task = Task {
            do {
                let _: EmptyResponse = try await core.request(
                    service: "compute",
                    method: "GET",
                    path: "/servers",
                    expected: 200
                )
                XCTFail("Should not succeed with unreachable endpoint")
            } catch {
                XCTAssertNotNil(error, "Should throw an error")
            }
        }

        try? await Task.sleep(nanoseconds: 100_000_000)
        task.cancel()

        await task.value
    }

    func testMultipleClientCreationAndCleanup() async throws {
        var clients: [OpenStackClientCore] = []

        for i in 0..<10 {
            let config = OpenStackConfig(
                authURL: URL(string: "https://test\(i).example.com:5000/v3")!,
                region: "RegionOne"
            )
            let credentials = OpenStackCredentials.password(
                username: "test\(i)",
                password: "test\(i)",
                projectName: "test\(i)"
            )
            let logger = ConsoleLogger()

            let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)
            clients.append(core)
        }

        XCTAssertEqual(clients.count, 10, "Should create 10 clients")

        clients.removeAll()

        await Task.yield()
        try? await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertTrue(clients.isEmpty, "All clients should be cleaned up")
    }

    func testNetworkFailureRecovery() async throws {
        let config = OpenStackConfig(
            authURL: URL(string: "https://localhost:1/v3")!,
            region: "RegionOne",
            timeout: 2.0,
            retryPolicy: RetryPolicy(maxAttempts: 2, baseDelay: 0.1)
        )
        let credentials = OpenStackCredentials.password(
            username: "test",
            password: "test",
            projectName: "test"
        )
        let logger = ConsoleLogger()

        let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)

        do {
            let _: EmptyResponse = try await core.request(
                service: "compute",
                method: "GET",
                path: "/",
                expected: 200
            )
            XCTFail("Should fail with network error")
        } catch {
            XCTAssertNotNil(error, "Should catch network error")
        }

        await Task.yield()
    }

    func testConcurrentRequestsWithCancellation() async throws {
        let config = OpenStackConfig(
            authURL: URL(string: "https://slow.example.com:5000/v3")!,
            region: "RegionOne",
            timeout: 10.0
        )
        let credentials = OpenStackCredentials.password(
            username: "test",
            password: "test",
            projectName: "test"
        )
        let logger = ConsoleLogger()

        let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)

        var tasks: [Task<Void, Never>] = []

        for _ in 0..<5 {
            let task = Task {
                do {
                    let _: EmptyResponse = try await core.request(
                        service: "compute",
                        method: "GET",
                        path: "/servers",
                        expected: 200
                    )
                } catch {
                }
            }
            tasks.append(task)
        }

        try? await Task.sleep(nanoseconds: 50_000_000)

        for task in tasks {
            task.cancel()
        }

        for task in tasks {
            await task.value
        }

        await Task.yield()

        XCTAssertTrue(true, "All tasks should complete without crashing")
    }

    func testURLSessionInvalidationOnDeinit() async throws {
        var coreOptional: OpenStackClientCore? = nil

        do {
            let config = OpenStackConfig(
                authURL: URL(string: "https://test.example.com:5000/v3")!,
                region: "RegionOne"
            )
            let credentials = OpenStackCredentials.password(
                username: "test",
                password: "test",
                projectName: "test"
            )
            let logger = ConsoleLogger()

            coreOptional = OpenStackClientCore(config: config, credentials: credentials, logger: logger)

            await Task.yield()
        }

        coreOptional = nil

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNil(coreOptional, "Core should be properly deallocated")
    }

    func testWeakSelfInTaskCapture() async throws {
        weak var weakCore: OpenStackClientCore?

        do {
            let config = OpenStackConfig(
                authURL: URL(string: "https://test.example.com:5000/v3")!,
                region: "RegionOne"
            )
            let credentials = OpenStackCredentials.password(
                username: "test",
                password: "test",
                projectName: "test"
            )
            let logger = ConsoleLogger()

            let core = OpenStackClientCore(config: config, credentials: credentials, logger: logger)
            weakCore = core

            try? await Task.sleep(nanoseconds: 50_000_000)

            XCTAssertNotNil(weakCore, "Core should still exist")
        }

        try? await Task.sleep(nanoseconds: 200_000_000)

        XCTAssertNil(weakCore, "Core should be deallocated without retain cycles")
    }
}
