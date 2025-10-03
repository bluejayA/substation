import Foundation

struct VolumeSourceTypeWrapper: FormSelectableItem {
    let type: VolumeSourceType

    var id: String {
        return "\(type.hashValue)"
    }

    var sortKey: String {
        return type.title
    }

    func matchesSearch(_ query: String) -> Bool {
        return type.title.lowercased().contains(query.lowercased())
    }
}

extension VolumeSourceType {
    var wrapped: VolumeSourceTypeWrapper {
        return VolumeSourceTypeWrapper(type: self)
    }

    static var wrappedAllCases: [VolumeSourceTypeWrapper] {
        return allCases.map { $0.wrapped }
    }
}
