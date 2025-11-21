import Foundation
import OSClient

extension Router: FormSelectableItem {
    var sortKey: String {
        return name ?? id
    }

    func matchesSearch(_ query: String) -> Bool {
        let lowercasedQuery = query.lowercased()
        if let name = name, name.lowercased().contains(lowercasedQuery) {
            return true
        }
        if id.lowercased().contains(lowercasedQuery) {
            return true
        }
        if let status = status, status.lowercased().contains(lowercasedQuery) {
            return true
        }
        if let description = description, description.lowercased().contains(lowercasedQuery) {
            return true
        }
        return false
    }

    func formattedColumns(columnWidths: [Int]) -> [String] {
        guard columnWidths.count >= 4 else { return [] }

        let nameColumn = String((name ?? "Unknown").prefix(columnWidths[0]))
            .padding(toLength: columnWidths[0], withPad: " ", startingAt: 0)

        let statusColumn = String((status ?? "Unknown").prefix(columnWidths[1]))
            .padding(toLength: columnWidths[1], withPad: " ", startingAt: 0)

        let adminStateColumn = String((adminStateUp == true ? "UP" : "DOWN").prefix(columnWidths[2]))
            .padding(toLength: columnWidths[2], withPad: " ", startingAt: 0)

        let idColumn = String(id.prefix(columnWidths[3]))
            .padding(toLength: columnWidths[3], withPad: " ", startingAt: 0)

        return [nameColumn, statusColumn, adminStateColumn, idColumn]
    }

    static var columnHeaders: [String] {
        return ["Name", "Status", "Admin State", "ID"]
    }

    static var columnWidths: [Int] {
        return [20, 15, 12, 36]
    }
}
