import Foundation
import OSClient

// MARK: - PortType FormSelectorItem Conformance

extension PortType: FormSelectableItem, FormSelectorItem {
    public var id: String { rawValue }
    public var sortKey: String { displayName }

    public var description: String {
        switch self {
        case .normal:
            return "Standard port for general use"
        case .direct:
            return "SR-IOV direct port for high performance"
        case .macvtap:
            return "Macvtap port for kernel-based virtualization"
        case .directPhysical:
            return "Direct physical port without virtualization"
        case .baremetal:
            return "Port for bare metal provisioning"
        case .virtioForwarder:
            return "Virtio forwarder for enhanced performance"
        case .smartNic:
            return "Smart NIC offload port"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               rawValue.lowercased().contains(lowercaseQuery)
    }
}
