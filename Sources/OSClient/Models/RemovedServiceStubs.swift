import Foundation

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