import Foundation
import OSClient

// MARK: - SecurityGroupDirection FormSelectorItem Conformance

extension SecurityGroupDirection: FormSelectableItem, FormSelectorItem {
    public var id: String { rawValue }
    public var sortKey: String { displayName }

    public var displayName: String {
        switch self {
        case .ingress: return "Ingress"
        case .egress: return "Egress"
        }
    }

    public var description: String {
        switch self {
        case .ingress: return "Inbound traffic to instances"
        case .egress: return "Outbound traffic from instances"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               rawValue.lowercased().contains(lowercaseQuery)
    }
}

// MARK: - SecurityGroupProtocol FormSelectorItem Conformance

extension SecurityGroupProtocol: FormSelectableItem, FormSelectorItem {
    public var sortKey: String { displayName }
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .tcp: return "TCP"
        case .udp: return "UDP"
        case .icmp: return "ICMP"
        case .any: return "Any"
        }
    }

    public var description: String {
        switch self {
        case .tcp: return "Transmission Control Protocol - reliable, connection-based"
        case .udp: return "User Datagram Protocol - fast, connectionless"
        case .icmp: return "Internet Control Message Protocol - ping, diagnostics"
        case .any: return "All protocols"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               rawValue.lowercased().contains(lowercaseQuery)
    }
}

// MARK: - SecurityGroupEtherType FormSelectorItem Conformance

extension SecurityGroupEtherType: FormSelectableItem, FormSelectorItem {
    public var sortKey: String { displayName }
    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .ipv4: return "IPv4"
        case .ipv6: return "IPv6"
        }
    }

    public var description: String {
        switch self {
        case .ipv4: return "Internet Protocol version 4"
        case .ipv6: return "Internet Protocol version 6"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               rawValue.lowercased().contains(lowercaseQuery)
    }
}

// MARK: - SecurityGroupPortType FormSelectorItem Conformance

extension SecurityGroupPortType: FormSelectableItem, FormSelectorItem {
    public var sortKey: String { displayName }
    public var id: String {
        switch self {
        case .all: return "all"
        case .custom: return "custom"
        }
    }

    public var displayName: String {
        switch self {
        case .all: return "All Ports"
        case .custom: return "Custom Range"
        }
    }

    public var description: String {
        switch self {
        case .all: return "Allow all ports (1-65535)"
        case .custom: return "Specify custom port or port range"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               id.lowercased().contains(lowercaseQuery)
    }
}

// MARK: - SecurityGroupRemoteType FormSelectorItem Conformance

extension SecurityGroupRemoteType: FormSelectableItem, FormSelectorItem {
    public var sortKey: String { displayName }
    public var id: String {
        switch self {
        case .cidr: return "cidr"
        case .securityGroup: return "security-group"
        }
    }

    public var displayName: String {
        switch self {
        case .cidr: return "CIDR"
        case .securityGroup: return "Security Group"
        }
    }

    public var description: String {
        switch self {
        case .cidr: return "IP address range in CIDR notation"
        case .securityGroup: return "Another security group"
        }
    }

    public func matchesSearch(_ query: String) -> Bool {
        let lowercaseQuery = query.lowercased()
        return displayName.lowercased().contains(lowercaseQuery) ||
               description.lowercased().contains(lowercaseQuery) ||
               id.lowercased().contains(lowercaseQuery)
    }
}
