import Foundation
import OSClient

// MARK: - SecurityGroupRule FormSelectorItem Conformance

extension SecurityGroupRule: FormSelectableItem {
    public var sortKey: String {
        return direction + (protocolEnum?.rawValue ?? "any") + id
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search by rule ID
        if id.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search by direction
        if direction.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search by protocol
        if let protocolValue = protocolEnum?.rawValue.lowercased(), protocolValue.contains(lowercaseQuery) {
            return true
        }

        // Search by ethertype
        if let ethertype = ethertype?.lowercased(), ethertype.contains(lowercaseQuery) {
            return true
        }

        // Search by remote IP
        if let remoteIp = remoteIpPrefix?.lowercased(), remoteIp.contains(lowercaseQuery) {
            return true
        }

        // Search by remote group ID
        if let remoteGroupId = remoteGroupId?.lowercased(), remoteGroupId.contains(lowercaseQuery) {
            return true
        }

        // Search by port range
        if let portMin = portRangeMin, String(portMin).contains(lowercaseQuery) {
            return true
        }

        if let portMax = portRangeMax, String(portMax).contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
