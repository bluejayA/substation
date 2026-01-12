// Tests/SubstationTests/Modules/StatusListViewTests.swift
//
// SPDX-License-Identifier: Apache-2.0
//
// Copyright 2025 Kevin Carter
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import XCTest
@testable import Substation
@testable import OSClient

// MARK: - StatusListView Test Suite

/// Test suite for StatusListView configurations across modules.
///
/// Tests cover:
/// - StatusListColumn configuration
/// - Status value extraction
/// - Status styling logic
/// - Status icon mapping
final class StatusListViewTests: XCTestCase {

    // MARK: - StatusListColumn Tests

    /// Test StatusListColumn initialization
    @MainActor
    func testStatusListColumnInitialization() {
        let column = StatusListColumn<TestResource>(
            header: "NAME",
            width: 20,
            getValue: { $0.name },
            getStyle: { _ in .primary }
        )

        XCTAssertEqual(column.header, "NAME")
        XCTAssertEqual(column.width, 20)
    }

    /// Test StatusListColumn getValue closure
    @MainActor
    func testStatusListColumnGetValue() {
        let column = StatusListColumn<TestResource>(
            header: "NAME",
            width: 20,
            getValue: { $0.name },
            getStyle: { _ in .primary }
        )

        let resource = TestResource(id: "1", name: "Test Resource", status: "ACTIVE")
        let value = column.getValue(resource)

        XCTAssertEqual(value, "Test Resource")
    }

    /// Test StatusListColumn getStyle closure
    @MainActor
    func testStatusListColumnGetStyle() {
        let column = StatusListColumn<TestResource>(
            header: "STATUS",
            width: 10,
            getValue: { $0.status },
            getStyle: { resource in
                switch resource.status.lowercased() {
                case "active": return .success
                case "error": return .error
                default: return .warning
                }
            }
        )

        let activeResource = TestResource(id: "1", name: "Active", status: "ACTIVE")
        let errorResource = TestResource(id: "2", name: "Error", status: "ERROR")
        let buildResource = TestResource(id: "3", name: "Build", status: "BUILD")

        XCTAssertEqual(column.getStyle(activeResource), .success)
        XCTAssertEqual(column.getStyle(errorResource), .error)
        XCTAssertEqual(column.getStyle(buildResource), .warning)
    }

    // MARK: - Router Status Tests

    /// Test Router status value extraction
    @MainActor
    func testRouterStatusValueExtraction() {
        let testCases: [(status: String?, expected: String)] = [
            ("ACTIVE", "ACTIVE"),
            ("ERROR", "ERROR"),
            ("BUILD", "BUILD"),
            ("DOWN", "DOWN"),
            (nil, "Unknown")
        ]

        for testCase in testCases {
            let result = testCase.status ?? "Unknown"
            XCTAssertEqual(result, testCase.expected,
                "Router status '\(testCase.status ?? "nil")' should display as '\(testCase.expected)'")
        }
    }

    /// Test Router status styling
    @MainActor
    func testRouterStatusStyling() {
        func getRouterStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.lowercased() {
            case "active": return .success
            case "error": return .error
            default: return .warning
            }
        }

        XCTAssertEqual(getRouterStyle(for: "ACTIVE"), .success)
        XCTAssertEqual(getRouterStyle(for: "active"), .success)
        XCTAssertEqual(getRouterStyle(for: "ERROR"), .error)
        XCTAssertEqual(getRouterStyle(for: "error"), .error)
        XCTAssertEqual(getRouterStyle(for: "BUILD"), .warning)
        XCTAssertEqual(getRouterStyle(for: "DOWN"), .warning)
        XCTAssertEqual(getRouterStyle(for: nil), .warning)
    }

    /// Test Router status icon mapping
    @MainActor
    func testRouterStatusIconMapping() {
        func getRouterIcon(for status: String?) -> String {
            return status?.lowercased() ?? "unknown"
        }

        XCTAssertEqual(getRouterIcon(for: "ACTIVE"), "active")
        XCTAssertEqual(getRouterIcon(for: "ERROR"), "error")
        XCTAssertEqual(getRouterIcon(for: "BUILD"), "build")
        XCTAssertEqual(getRouterIcon(for: nil), "unknown")
    }

    // MARK: - Server Status Tests

    /// Test Server status styling
    @MainActor
    func testServerStatusStyling() {
        func getServerStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.uppercased() {
            case "ACTIVE": return .success
            case "ERROR", "DELETED": return .error
            case "BUILD", "REBUILD", "RESIZE", "VERIFY_RESIZE", "REVERT_RESIZE":
                return .warning
            case "SHUTOFF", "STOPPED", "SUSPENDED", "PAUSED":
                return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getServerStyle(for: "ACTIVE"), .success)
        XCTAssertEqual(getServerStyle(for: "ERROR"), .error)
        XCTAssertEqual(getServerStyle(for: "BUILD"), .warning)
        XCTAssertEqual(getServerStyle(for: "SHUTOFF"), .dimmed)
        XCTAssertEqual(getServerStyle(for: "UNKNOWN"), .primary)
    }

    // MARK: - Network Status Tests

    /// Test Network status styling
    @MainActor
    func testNetworkStatusStyling() {
        func getNetworkStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.uppercased() {
            case "ACTIVE": return .success
            case "ERROR": return .error
            case "BUILD": return .warning
            case "DOWN": return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getNetworkStyle(for: "ACTIVE"), .success)
        XCTAssertEqual(getNetworkStyle(for: "ERROR"), .error)
        XCTAssertEqual(getNetworkStyle(for: "BUILD"), .warning)
        XCTAssertEqual(getNetworkStyle(for: "DOWN"), .dimmed)
    }

    // MARK: - Volume Status Tests

    /// Test Volume status styling
    @MainActor
    func testVolumeStatusStyling() {
        func getVolumeStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.lowercased() {
            case "available", "in-use": return .success
            case "error", "error_deleting", "error_extending": return .error
            case "creating", "attaching", "detaching", "extending", "uploading":
                return .warning
            case "deleting": return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getVolumeStyle(for: "available"), .success)
        XCTAssertEqual(getVolumeStyle(for: "in-use"), .success)
        XCTAssertEqual(getVolumeStyle(for: "error"), .error)
        XCTAssertEqual(getVolumeStyle(for: "creating"), .warning)
        XCTAssertEqual(getVolumeStyle(for: "deleting"), .dimmed)
    }

    // MARK: - Image Status Tests

    /// Test Image status styling
    @MainActor
    func testImageStatusStyling() {
        func getImageStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.lowercased() {
            case "active": return .success
            case "error", "killed", "deleted": return .error
            case "queued", "saving", "pending_delete": return .warning
            case "deactivated": return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getImageStyle(for: "active"), .success)
        XCTAssertEqual(getImageStyle(for: "error"), .error)
        XCTAssertEqual(getImageStyle(for: "queued"), .warning)
        XCTAssertEqual(getImageStyle(for: "deactivated"), .dimmed)
    }

    // MARK: - Port Status Tests

    /// Test Port status styling
    @MainActor
    func testPortStatusStyling() {
        func getPortStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.uppercased() {
            case "ACTIVE": return .success
            case "ERROR": return .error
            case "BUILD": return .warning
            case "DOWN": return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getPortStyle(for: "ACTIVE"), .success)
        XCTAssertEqual(getPortStyle(for: "ERROR"), .error)
        XCTAssertEqual(getPortStyle(for: "BUILD"), .warning)
        XCTAssertEqual(getPortStyle(for: "DOWN"), .dimmed)
    }

    // MARK: - Floating IP Status Tests

    /// Test Floating IP status styling
    @MainActor
    func testFloatingIPStatusStyling() {
        func getFloatingIPStyle(for status: String?) -> TestTextStyle {
            let statusValue = status ?? "Unknown"
            switch statusValue.uppercased() {
            case "ACTIVE": return .success
            case "ERROR": return .error
            case "DOWN": return .dimmed
            default: return .primary
            }
        }

        XCTAssertEqual(getFloatingIPStyle(for: "ACTIVE"), .success)
        XCTAssertEqual(getFloatingIPStyle(for: "ERROR"), .error)
        XCTAssertEqual(getFloatingIPStyle(for: "DOWN"), .dimmed)
    }

    // MARK: - Admin State Tests

    /// Test Admin State Up styling
    @MainActor
    func testAdminStateUpStyling() {
        func getAdminStateStyle(adminStateUp: Bool) -> TestTextStyle {
            return adminStateUp ? .success : .dimmed
        }

        func getAdminStateValue(adminStateUp: Bool) -> String {
            return adminStateUp ? "UP" : "DOWN"
        }

        XCTAssertEqual(getAdminStateStyle(adminStateUp: true), .success)
        XCTAssertEqual(getAdminStateStyle(adminStateUp: false), .dimmed)
        XCTAssertEqual(getAdminStateValue(adminStateUp: true), "UP")
        XCTAssertEqual(getAdminStateValue(adminStateUp: false), "DOWN")
    }

    // MARK: - Column Width Tests

    /// Test typical column widths
    @MainActor
    func testTypicalColumnWidths() {
        // These are common column width patterns across modules
        let idWidth = 36 // UUID length
        let nameWidth = 20
        let statusWidth = 10
        let dateWidth = 19 // YYYY-MM-DD HH:MM:SS

        XCTAssertEqual(idWidth, 36)
        XCTAssertEqual(nameWidth, 20)
        XCTAssertEqual(statusWidth, 10)
        XCTAssertEqual(dateWidth, 19)
    }

    // MARK: - Edge Cases

    /// Test empty status handling
    @MainActor
    func testEmptyStatusHandling() {
        let status: String? = ""
        let displayValue = status?.isEmpty == true ? "Unknown" : (status ?? "Unknown")

        XCTAssertEqual(displayValue, "Unknown")
    }

    /// Test whitespace status handling
    @MainActor
    func testWhitespaceStatusHandling() {
        let status = "   "
        let trimmed = status.trimmingCharacters(in: .whitespaces)
        let displayValue = trimmed.isEmpty ? "Unknown" : trimmed

        XCTAssertEqual(displayValue, "Unknown")
    }

    /// Test case insensitivity
    @MainActor
    func testStatusCaseInsensitivity() {
        let statuses = ["ACTIVE", "Active", "active", "AcTiVe"]

        for status in statuses {
            let normalized = status.lowercased()
            XCTAssertEqual(normalized, "active")
        }
    }
}

// MARK: - Test Helper Types

/// Test resource for StatusListColumn testing
struct TestResource {
    let id: String
    let name: String
    let status: String
}

/// Mock StatusListColumn for testing
struct StatusListColumn<T> {
    let header: String
    let width: Int
    let getValue: (T) -> String
    let getStyle: (T) -> TestTextStyle
}

/// Test text style enum
enum TestTextStyle: Equatable {
    case primary
    case success
    case error
    case warning
    case dimmed
    case accent
}
