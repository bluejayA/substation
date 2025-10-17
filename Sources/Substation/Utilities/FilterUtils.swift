import Foundation
import struct OSClient.Port
import OSClient

struct FilterUtils {
    static func filterServers(_ servers: [Server], query: String?, getServerIP: ((Server) -> String?)? = nil) -> [Server] {
        guard let query = query?.lowercased() else { return servers }
        return servers.filter { server in
            server.name?.lowercased().contains(query) == true ||
            server.status?.lowercased().contains(query) == true ||
            server.id.lowercased().contains(query) ||
            (getServerIP?(server)?.lowercased().contains(query) == true)
        }
    }

    static func filterServerGroups(_ serverGroups: [ServerGroup], query: String?) -> [ServerGroup] {
        guard let query = query?.lowercased() else { return serverGroups }
        return serverGroups.filter { serverGroup in
            serverGroup.name?.lowercased().contains(query) == true ||
            serverGroup.primaryPolicy?.displayName.lowercased().contains(query) == true ||
            serverGroup.primaryPolicy?.rawValue.lowercased().contains(query) == true ||
            serverGroup.id.lowercased().contains(query)
        }
    }

    static func filterSecurityGroups(_ securityGroups: [SecurityGroup], query: String?) -> [SecurityGroup] {
        guard let query = query?.lowercased() else { return securityGroups }
        return securityGroups.filter { securityGroup in
            securityGroup.name?.lowercased().contains(query) == true ||
            securityGroup.description?.lowercased().contains(query) == true ||
            securityGroup.id.lowercased().contains(query)
        }
    }

    static func filterNetworks(_ networks: [Network], query: String?) -> [Network] {
        guard let query = query?.lowercased() else { return networks }
        return networks.filter { network in
            network.name?.lowercased().contains(query) == true ||
            network.status?.lowercased().contains(query) == true ||
            network.id.lowercased().contains(query)
        }
    }

    static func filterVolumes(_ volumes: [Volume], query: String?) -> [Volume] {
        guard let query = query?.lowercased() else { return volumes }
        return volumes.filter { volume in
            volume.name?.lowercased().contains(query) == true ||
            volume.status?.lowercased().contains(query) == true ||
            volume.id.lowercased().contains(query)
        }
    }

    static func filterImages(_ images: [Image], query: String?) -> [Image] {
        guard let query = query?.lowercased() else { return images }
        return images.filter { image in
            image.name?.lowercased().contains(query) == true ||
            image.status?.lowercased().contains(query) == true ||
            image.id.lowercased().contains(query)
        }
    }

    static func filterFlavors(_ flavors: [Flavor], query: String?) -> [Flavor] {
        guard let query = query?.lowercased() else { return flavors }
        return flavors.filter { flavor in
            flavor.name?.lowercased().contains(query) == true ||
            flavor.id.lowercased().contains(query)
        }
    }

    static func filterKeyPairs(_ keyPairs: [KeyPair], query: String?) -> [KeyPair] {
        guard let query = query?.lowercased() else { return keyPairs }
        return keyPairs.filter { keyPair in
            keyPair.name?.lowercased().contains(query) == true ||
            keyPair.type?.lowercased().contains(query) == true ||
            keyPair.fingerprint?.lowercased().contains(query) == true
        }
    }

    static func filterSubnets(_ subnets: [Subnet], query: String?) -> [Subnet] {
        guard let query = query?.lowercased() else { return subnets }
        return subnets.filter { subnet in
            subnet.name?.lowercased().contains(query) == true ||
            subnet.id.lowercased().contains(query) ||
            subnet.networkId.lowercased().contains(query)
        }
    }

    static func filterPorts(_ ports: [Port], query: String?) -> [Port] {
        let filtered: [Port]
        if let query = query?.lowercased() {
            filtered = ports.filter { port in
                port.name?.lowercased().contains(query) == true ||
                port.id.lowercased().contains(query) ||
                port.networkId.lowercased().contains(query) ||
                port.deviceId?.lowercased().contains(query) == true
            }
        } else {
            filtered = ports
        }

        // Sort alphabetically by name (case-insensitive), with unnamed ports (using ID) at the end
        return filtered.sorted { port1, port2 in
            let name1 = port1.name?.lowercased() ?? "~\(port1.id)" // ~ sorts after letters
            let name2 = port2.name?.lowercased() ?? "~\(port2.id)"
            return name1 < name2
        }
    }

    static func filterRouters(_ routers: [Router], query: String?) -> [Router] {
        guard let query = query?.lowercased() else { return routers }
        return routers.filter { router in
            router.name?.lowercased().contains(query) == true ||
            router.id.lowercased().contains(query)
        }
    }

    static func filterFloatingIPs(_ floatingIPs: [FloatingIP], query: String?) -> [FloatingIP] {
        guard let queryLower = query?.lowercased() else { return floatingIPs }
        return floatingIPs.filter { floatingIP in
            // Use localizedStandardContains for better performance (optimized by Swift runtime)
            if let ip = floatingIP.floatingIpAddress, ip.localizedStandardContains(queryLower) {
                return true
            }
            if floatingIP.id.localizedStandardContains(queryLower) {
                return true
            }
            if let portId = floatingIP.portId, portId.localizedStandardContains(queryLower) {
                return true
            }
            return false
        }
    }

    static func filterLines(_ lines: [String], query: String?) -> [String] {
        guard let query = query?.lowercased() else { return lines }
        return lines.filter { $0.lowercased().contains(query) }
    }

    /// Filter images to return only server snapshots
    /// Checks metadata for source_server_id or name containing "snapshot"
    static func filterServerSnapshots(_ images: [Image]) -> [Image] {
        return images.filter { image in
            // First priority: Check metadata for source_server_id
            if let metadata = image.metadata, metadata["source_server_id"] != nil {
                return true
            }
            // Legacy fallback: Check if image name contains "snapshot" (case insensitive)
            if let name = image.name, name.lowercased().contains("snapshot") {
                return true
            }
            return false
        }
    }
}