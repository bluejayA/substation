import OSClient

extension Server: FormSelectableItem {
    var sortKey: String {
        return name ?? id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()

        if let name = name, name.lowercased().contains(lowercaseQuery) {
            return true
        }

        if id.lowercased().contains(lowercaseQuery) {
            return true
        }

        if let status = status?.rawValue, status.lowercased().contains(lowercaseQuery) {
            return true
        }

        // Search in IP addresses
        if let addresses = addresses {
            for (_, addressList) in addresses {
                for address in addressList {
                    if address.addr.lowercased().contains(lowercaseQuery) {
                        return true
                    }
                }
            }
        }

        return false
    }
}
