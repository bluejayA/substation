import Foundation
import OSClient

extension AddressPair: FormSelectableItem {
    public var sortKey: String {
        return ipAddress
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        // Search in IP address
        if ipAddress.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in MAC address
        if let macAddress = macAddress, macAddress.lowercased().contains(lowercaseQuery) {
            return true
        }

        return false
    }
}
