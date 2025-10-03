import Foundation

// MARK: - Swift Object Storage Stubs
// These types are stubs for removed Swift Object Storage service
// Views exist but service was removed as dead code

public struct SwiftContainer: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let count: Int
    public let bytes: Int

    public init(id: String, name: String, count: Int, bytes: Int) {
        self.id = id
        self.name = name
        self.count = count
        self.bytes = bytes
    }
}

public struct SwiftObject: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let bytes: Int
    public let contentType: String
    public let lastModified: Date

    public init(id: String, name: String, bytes: Int, contentType: String, lastModified: Date) {
        self.id = id
        self.name = name
        self.bytes = bytes
        self.contentType = contentType
        self.lastModified = lastModified
    }
}

// MARK: - Octavia Load Balancer Stubs
// These types are stubs for removed Octavia service
// Views exist but service was removed as dead code

public struct LoadBalancer: Codable, Sendable, Identifiable {
    public let id: String
    public let name: String
    public let provisioningStatus: String
    public let operatingStatus: String
    public let vipAddress: String

    public init(id: String, name: String, provisioningStatus: String, operatingStatus: String, vipAddress: String) {
        self.id = id
        self.name = name
        self.provisioningStatus = provisioningStatus
        self.operatingStatus = operatingStatus
        self.vipAddress = vipAddress
    }
}